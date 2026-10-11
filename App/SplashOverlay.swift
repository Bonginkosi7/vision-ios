import SwiftUI
import Darwin
import VisionCore

/// The same picture as the launch screen (near-black, the VISION mark, "Powered by Ann-Connect"), kept on screen
/// until the splash has been up for [SplashTiming.minimumSeconds] from the moment the app started, so it can actually be seen.
/// The launch screen itself ends as soon as the app can draw; the real app is already running underneath.
struct SplashOverlay: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .accessibilityHidden(true)
            VStack {
                Spacer()
                Text("Powered by Ann-Connect")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.bottom, 24)
                    .accessibilityIdentifier("splashPoweredBy")
            }
        }
    }

    /// When this process started — the splash is timed from here, not from when SwiftUI first runs.
    static func processStart() -> Date {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0 else { return Date() }
        let started = info.kp_proc.p_un.__p_starttime
        return Date(timeIntervalSince1970: TimeInterval(started.tv_sec) + TimeInterval(started.tv_usec) / 1_000_000)
    }

    /// How much longer the splash has to stay up (0 when it has already had its time).
    static func remainingSeconds(now: Date = Date()) -> TimeInterval {
        SplashTiming.remaining(processStart: processStart(), now: now)
    }
}
