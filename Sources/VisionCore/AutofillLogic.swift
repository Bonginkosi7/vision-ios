import Foundation

/// Port of desktop's autofill.ts buildFillScript (and Android's AutofillLogic.kt). The page's own
/// scripts only see a value change when it goes through the native setter and real input/change
/// events — a plain `el.value = x` is invisible to React/Vue-controlled fields — so the script does that.
/// Values are JSON-encoded, never string-concatenated, so a quote or `</script>` in a username or
/// password can't break out of the script.
public enum AutofillLogic {
    /// scheme://host[:port] — the real tuple origin. Credentials are matched on this exactly, never fuzzily.
    public static func originOf(_ urlString: String) -> String? {
        guard let components = URLComponents(string: urlString),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host?.lowercased(), !host.isEmpty
        else { return nil }
        if let port = components.port { return "\(scheme)://\(host):\(port)" }
        return "\(scheme)://\(host)"
    }

    /// The origin the user typed in Settings — accepts a bare "example.com" and returns its https origin.
    public static func normalizedOrigin(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if let origin = originOf(trimmed) { return origin }
        return originOf("https://\(trimmed)")
    }

    private static func jsonString(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let array = String(data: data, encoding: .utf8)
        else { return "\"\"" }
        // ["…"] → "…"
        return String(array.dropFirst().dropLast())
    }

    public static func buildFillScript(username: String?, password: String) -> String {
        let usernameJson = username.map(jsonString) ?? "null"
        let passwordJson = jsonString(password)
        return """
        (function () {
            function setNativeValue(el, value) {
                var proto = Object.getPrototypeOf(el);
                var desc = Object.getOwnPropertyDescriptor(proto, "value");
                desc.set.call(el, value);
                el.dispatchEvent(new Event("input", { bubbles: true }));
                el.dispatchEvent(new Event("change", { bubbles: true }));
            }
            var pwInputs = Array.from(document.querySelectorAll('input[type="password"]')).filter(function (el) { return el.offsetParent !== null; });
            if (pwInputs.length === 0) return false;
            var pwInput = pwInputs[0];
            var usernameJson = \(usernameJson);
            if (usernameJson !== null) {
                var form = pwInput.form;
                var scope = form ? Array.from(form.querySelectorAll("input")) : Array.from(document.querySelectorAll("input"));
                var pwIndex = scope.indexOf(pwInput);
                var userInput = null;
                for (var i = pwIndex - 1; i >= 0; i--) {
                    var type = (scope[i].type || "text").toLowerCase();
                    if (type === "email" || type === "text" || type === "tel") {
                        userInput = scope[i];
                        break;
                    }
                }
                if (userInput) setNativeValue(userInput, usernameJson);
            }
            setNativeValue(pwInput, \(passwordJson));
            return true;
        })();
        """
    }
}
