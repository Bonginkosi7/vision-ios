import Foundation
import CryptoKit
import Security
import VisionCore

/// What VISION learns about the certificate that failed.
struct CertificateFailure {
    let url: URL
    let host: String
    let code: Int
    /// SHA-256 of the leaf certificate, nil when the system didn't hand over a certificate.
    let fingerprint: String?
    let subject: String
    let issuer: String

    init?(error: NSError) {
        guard error.domain == NSURLErrorDomain,
              CertificateErrorLogic.isCertificateError(code: error.code),
              let url = error.userInfo[NSURLErrorFailingURLErrorKey] as? URL,
              let host = url.host
        else { return nil }
        self.url = url
        self.host = host
        self.code = error.code
        // Foundation's key for the failed certificate chain; checked by CF type before it is used as a SecTrust.
        let rawTrust = error.userInfo["NSURLErrorFailingURLPeerTrustErrorKey"] as CFTypeRef?
        let trust: SecTrust? = rawTrust.flatMap { CFGetTypeID($0) == SecTrustGetTypeID() ? ($0 as! SecTrust) : nil }
        let chain = trust.map { CertificateErrorPage.chain(of: $0) } ?? []
        fingerprint = chain.first.map(CertificateErrorPage.fingerprint)
        subject = chain.first.flatMap { SecCertificateCopySubjectSummary($0) as String? } ?? "Unknown"
        issuer = (chain.count > 1 ? chain[1] : chain.first).flatMap { SecCertificateCopySubjectSummary($0) as String? } ?? "Unknown"
    }
}

/// The in-tab "your connection isn't private" page, shown instead of the failed page — the iOS counterpart
/// of desktop's vision://app/cert-error and Android's SslErrorPage.kt. Its two buttons post to a real
/// WKScriptMessageHandler ("sslBridge", see WebViewRepresentable.swift).
enum CertificateErrorPage {
    static func chain(of trust: SecTrust) -> [SecCertificate] {
        (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []
    }

    static func fingerprint(_ certificate: SecCertificate) -> String {
        let data = SecCertificateCopyData(certificate) as Data
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func fingerprint(of trust: SecTrust) -> String? {
        chain(of: trust).first.map(fingerprint)
    }

    static func html(for failure: CertificateFailure) -> String {
        let esc = CertificateErrorLogic.escapeHTML
        let host = esc(failure.host)
        let canProceed = failure.fingerprint != nil
        let fingerprint = failure.fingerprint.map { esc($0) } ?? "Not available"
        let proceedButton = canProceed ? "<button id=\"proceed-btn\" onclick=\"proceed()\">Proceed to \(host) (unsafe)</button>" : ""
        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Connection not private</title>
          <style>
            body { font-family: -apple-system, sans-serif; background: #0A0A0A; color: #F2F2F7; display: flex; flex-direction: column;
                   align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 24px; text-align: center; box-sizing: border-box; }
            h1 { font-size: 22px; margin-bottom: 8px; max-width: 480px; }
            p { color: #9A9AA6; font-size: 15px; max-width: 480px; line-height: 1.5; }
            #reason { color: #F2F2F7; font-weight: 500; }
            .buttons { display: flex; flex-direction: column; gap: 10px; margin-top: 20px; width: 100%; max-width: 320px; }
            button { border: none; border-radius: 12px; padding: 14px 24px; font-size: 16px; }
            #back-btn { background: #FFFFFF; color: #0A0A0A; font-weight: 600; }
            #advanced-toggle { background: transparent; color: #9A9AA6; text-decoration: underline; padding: 8px; }
            #proceed-btn { background: #2A2A2E; color: #F2F2F7; margin-top: 12px; width: 100%; }
            #advanced-panel { display: none; text-align: left; background: #151517; border-radius: 12px; padding: 16px; margin-top: 8px; max-width: 480px; width: 100%; box-sizing: border-box; font-size: 12px; }
            #advanced-panel div { margin-bottom: 6px; word-break: break-all; }
            #advanced-panel b { color: #9A9AA6; font-weight: 500; }
          </style>
        </head>
        <body>
          <h1 id="title">Your connection to \(host) isn't private</h1>
          <p>VISION blocked this page because its certificate couldn't be verified — someone could be trying to intercept your connection, or the site may just be misconfigured.</p>
          <p id="reason">\(esc(CertificateErrorLogic.reason(forCode: failure.code)))</p>
          <div class="buttons">
            <button id="back-btn" onclick="window.webkit.messageHandlers.sslBridge.postMessage('goBack')">Back to safety</button>
            <button id="advanced-toggle" onclick="toggleAdvanced()">Advanced</button>
          </div>
          <div id="advanced-panel">
            <div><b>Error:</b> \(esc(CertificateErrorLogic.errorName(forCode: failure.code)))</div>
            <div><b>Certificate for:</b> \(esc(failure.subject))</div>
            <div><b>Issued by:</b> \(esc(failure.issuer))</div>
            <div><b>SHA-256:</b> \(fingerprint)</div>
            \(proceedButton)
          </div>
          <script>
            function toggleAdvanced() {
              var panel = document.getElementById('advanced-panel');
              var shown = panel.style.display === 'block';
              panel.style.display = shown ? 'none' : 'block';
              document.getElementById('advanced-toggle').textContent = shown ? 'Advanced' : 'Hide advanced';
            }
            function proceed() {
              var b = document.getElementById('proceed-btn');
              b.textContent = 'Proceeding…';
              b.disabled = true;
              window.webkit.messageHandlers.sslBridge.postMessage('proceed');
            }
          </script>
        </body>
        </html>
        """
    }
}
