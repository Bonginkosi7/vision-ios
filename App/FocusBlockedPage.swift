import Foundation

/// The in-tab "blocked" page, loaded via WKWebView.loadHTMLString instead
/// of the real navigation — direct port of FocusBlockedPage.kt. The
/// countdown runs as real client-side JS against the real endsAt
/// timestamp — not a static string that goes stale. The "End session"
/// button posts to a real WKScriptMessageHandler ("focusBridge", see
/// WebViewRepresentable.swift) instead of Android's
/// @JavascriptInterface — the direct WKWebView equivalent.
enum FocusBlockedPage {
    static func html(domain: String, endsAt: Date) -> String {
        let escapedDomain = domain.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
        let endsAtMillis = Int64(endsAt.timeIntervalSince1970 * 1000)
        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            body { font-family: -apple-system, sans-serif; background: #0A0D16; color: #F2F2F7; display: flex; flex-direction: column;
                   align-items: center; justify-content: center; height: 100vh; margin: 0; padding: 24px; text-align: center; box-sizing: border-box; }
            h1 { font-size: 22px; margin-bottom: 8px; }
            p { color: #8890A6; font-size: 15px; }
            #countdown { font-size: 32px; font-weight: bold; margin: 24px 0; font-variant-numeric: tabular-nums; }
            button { background: linear-gradient(135deg, #7B3FF2, #3B6FFF); color: white; border: none; border-radius: 8px;
                     padding: 12px 24px; font-size: 15px; }
          </style>
        </head>
        <body>
          <h1>\(escapedDomain) is blocked right now.</h1>
          <p id="subtext">Blocked while your focus session is active.</p>
          <div id="countdown"></div>
          <button onclick="window.webkit.messageHandlers.focusBridge.postMessage('endSession')">End session</button>
          <script>
            var endsAt = \(endsAtMillis);
            function tick() {
              var remaining = Math.max(0, endsAt - Date.now());
              var mins = Math.floor(remaining / 60000);
              var secs = Math.floor((remaining % 60000) / 1000);
              document.getElementById('countdown').textContent =
                mins + ':' + (secs < 10 ? '0' : '') + secs + ' left in this session';
            }
            tick();
            window.__tickInterval = setInterval(tick, 1000);
          </script>
        </body>
        </html>
        """
    }
}
