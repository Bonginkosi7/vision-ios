import Foundation
import VisionCore

/// Real anonymous product-usage analytics — the iOS counterpart of
/// desktop's AnalyticsClient.ts / Android's AnalyticsClient.kt, talking to
/// the exact same real vision-analytics-backend over the exact same HTTP
/// protocol (POST /v1/events batched, POST /v1/crashes one at a time),
/// using this app's existing hand-rolled URLSession style
/// (FirestoreRestClient.swift) rather than a new SDK dependency.
///
/// Same real anonymity shape as Android/desktop: a random per-install
/// UUID, never a device identifier, never tied to any other VISION account
/// or user data. `track()`/`reportCrash()` are real no-ops (not errors)
/// when their respective setting is off, or until `start()` has run once —
/// callers never need to check either condition themselves, and both stay
/// plain synchronous calls (fire-and-forget into an internal `Task`) so any
/// call site can use them without `await`, matching how cheap/non-blocking
/// Android's/desktop's own synchronous local-DB calls are.
///
/// **Disclosed scope trim**: Android schedules a real periodic background
/// flush via WorkManager (`AnalyticsFlushWorker.kt`); iOS has no
/// background-task infrastructure built yet at all (confirmed nothing else
/// in this repo uses `BGTaskScheduler` either — `RedemptionStore`'s own
/// disclosure says the same). This instead matches desktop's model: a real,
/// repeating `Timer` flushes every `AnalyticsConfig.flushIntervalSeconds`
/// while the app is foregrounded, not truly in the background once
/// suspended — desktop's own `setInterval` only runs while its process is
/// alive either, so this isn't a smaller behavior than desktop's, only
/// smaller than Android's.
@MainActor
final class AnalyticsClient {
    static let shared = AnalyticsClient()
    private init() {}

    private var queue: AnalyticsQueueStore?
    private var flushTimer: Timer?
    private var flushInFlight = false

    /// Call once at process start (`VisionIOSApp.init`). Ensures a real
    /// anonymous installation ID exists and fires the one-time
    /// install/first-open events, or the ordinary per-launch "opened" event
    /// on every subsequent run — same real logic as the other two ports'
    /// own init()/initAnalytics().
    func start() {
        let queue = AnalyticsQueueStore()
        self.queue = queue

        var installationID = AppSettings.analyticsInstallationID
        let isFirstEverLaunch = installationID == nil
        if isFirstEverLaunch {
            installationID = UUID().uuidString
            AppSettings.analyticsInstallationID = installationID
        }

        if isFirstEverLaunch {
            track(AnalyticsEvent.appInstalled)
            track(AnalyticsEvent.appFirstOpened)
        } else {
            track(AnalyticsEvent.appOpened)
        }

        flushTimer?.invalidate()
        // Referencing the singleton fresh (not capturing `self`) sidesteps a
        // real concurrency-safety complaint the local Swift 5.8 toolchain
        // catches but CI's newer one only warns on: a weakly-captured `self`
        // referenced from a Task nested inside Timer's own non-isolated,
        // concurrently-executing callback. Safe here since there's only ever
        // one AnalyticsClient, held for the app's entire lifetime anyway.
        flushTimer = Timer.scheduledTimer(withTimeInterval: AnalyticsConfig.flushIntervalSeconds, repeats: true) { _ in
            Task { @MainActor in await AnalyticsClient.shared.flush() }
        }
        Task { await flush() } // don't wait a full interval after a fresh launch to try sending
    }

    /// No-ops silently when analytics is off or `start()` hasn't run yet.
    func track(_ eventName: String, properties: [String: Any] = [:]) {
        guard let queue, AppSettings.isAnalyticsEnabled else { return }
        let id = UUID().uuidString
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        Task { await queue.enqueueEvent(id: id, eventName: eventName, properties: properties, clientTimestamp: timestamp) }
    }

    /// No-ops silently when diagnostics is off or `start()` hasn't run yet.
    /// Stack trace capped at 4000 chars, same real bound as the other two
    /// ports' own `reportCrash()`.
    func reportCrash(component: String?, errorType: String?, stackTrace: String?) {
        guard let queue, AppSettings.isDiagnosticsEnabled else { return }
        let id = UUID().uuidString
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let truncated = stackTrace.map { String($0.prefix(4000)) }
        Task { await queue.enqueueCrash(id: id, component: component, errorType: errorType, stackTrace: truncated, clientTimestamp: timestamp) }
    }

    /// Called periodically by the real `Timer` above. A genuine network
    /// attempt only happens when `AnalyticsConfig.isConfigured()` —
    /// otherwise this is a cheap no-op, same real "queue locally, only
    /// actually try to leave the device once a real backend URL exists"
    /// reasoning `AnalyticsConfig`'s own doc comment gives (true right now:
    /// no vision-analytics-backend has been deployed yet). Offline or an
    /// unreachable backend is never surfaced to the user: the queue just
    /// keeps growing (bounded by `AnalyticsQueueStore`'s own cap) until the
    /// next tick finds a working connection — VISION works the same with or
    /// without analytics reachable, matching Android/desktop's own real
    /// behavior exactly.
    func flush() async {
        let queue = queue ?? AnalyticsQueueStore()
        self.queue = queue
        guard AnalyticsConfig.isConfigured(), !flushInFlight else { return }
        flushInFlight = true
        await flushEvents(queue)
        await flushCrashes(queue)
        flushInFlight = false
    }

    private func flushEvents(_ queue: AnalyticsQueueStore) async {
        guard let installationID = AppSettings.analyticsInstallationID else { return }
        let batch = await queue.dequeueEventBatch(limit: AnalyticsConfig.eventBatchSize)
        guard !batch.isEmpty else { return }

        let events = batch.map { event -> [String: Any] in
            [
                "event_id": event.id, "event_name": event.eventName, "installation_id": installationID,
                "app_version": Self.appVersion, "platform": "ios",
                "properties": AnalyticsQueueStore.decodeProperties(event.properties),
                "client_timestamp": event.clientTimestamp,
            ]
        }

        let (ok, status) = await Self.postJSON("\(AnalyticsConfig.baseURL)/v1/events", body: ["events": events])
        // Whether the server accepted, deduped, or rejected each event, it
        // has rendered a final verdict — retrying a rejected event won't
        // change the outcome (it failed validation deterministically), and
        // retrying an accepted/duplicate one would be pointless. Any other
        // status (401 misconfigured write key, 5xx, network-level failure)
        // leaves the batch queued for the next attempt. Same real logic as
        // the other two ports' own flushEvents().
        if ok || status == 400 {
            await queue.removeEvents(batch.map(\.id))
        }
    }

    private func flushCrashes(_ queue: AnalyticsQueueStore) async {
        guard let installationID = AppSettings.analyticsInstallationID else { return }
        let batch = await queue.dequeueCrashBatch(limit: AnalyticsConfig.crashBatchSize)
        var sentIDs: [String] = []
        for crash in batch {
            // Plain `as Any` on a nil String? doesn't become JSON `null` —
            // JSONSerialization needs an explicit NSNull for that.
            let rawBody: [String: Any?] = [
                "installation_id": installationID, "app_version": Self.appVersion, "platform": "ios",
                "component": crash.component, "error_type": crash.errorType,
                "stack_trace": crash.stackTrace, "client_timestamp": crash.clientTimestamp,
            ]
            let (ok, _) = await Self.postJSON("\(AnalyticsConfig.baseURL)/v1/crashes", body: rawBody.mapValues { $0 ?? NSNull() })
            if ok {
                sentIDs.append(crash.id)
            } else {
                break // stop this batch on the first failure; the rest retry next tick — same real logic as Android/desktop.
            }
        }
        await queue.removeCrashes(sentIDs)
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private static func postJSON(_ urlString: String, body: [String: Any]) async -> (ok: Bool, status: Int) {
        guard let url = URL(string: urlString), let payload = try? JSONSerialization.data(withJSONObject: body) else { return (false, -1) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AnalyticsConfig.writeKey, forHTTPHeaderField: "x-vision-write-key")
        request.httpBody = payload
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            return (ok: (200..<300).contains(status), status: status)
        } catch {
            return (false, -1)
        }
    }
}
