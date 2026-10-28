import Foundation
import TapaCore

/// The page a blocked tab lands on: a misty photo, a quiet line, how long is left, and a way back.
/// While it's open it asks the tracker whether the site is still blocked, and returns to where the
/// tab was once it isn't.
struct MistPage {
    let site: DomainName
    let returnAddress: String?
    let snapshot: SessionSnapshot?
    let photo: String
    let openToken: String

    static let photos = ["mist-peaks-in-fog", "mist-sea-of-clouds", "mist-peak-above-clouds", "mist-bed-of-clouds"]

    private static let lines = [
        "This path leads to distraction.",
        "The summit is the other way.",
        "This trail leads nowhere you meant to go.",
        "Leave it at basecamp for now.",
        "The view from here can wait.",
    ]

    /// Summit Mode was sworn to with The Summit Oath, so some lines recall it.
    private static let summitLines = lines + [
        "You left this at the foot of the mountain.",
        "Your watch has not ended.",
        "Words are kept, not taken back.",
        "You gave your word at the start of this climb.",
    ]

    private var isSummit: Bool { snapshot?.mode == .summit }

    var html: String {
        let line = (isSummit ? Self.summitLines : Self.lines).randomElement() ?? Self.lines[0]
        let endsAt = snapshot?.endsAt.map { Int($0.timeIntervalSince1970 * 1000) }
        return Self.template
            .replacingOccurrences(of: "{{photo}}", with: Self.escaped(photo))
            .replacingOccurrences(of: "{{line}}", with: Self.escaped(line))
            .replacingOccurrences(of: "{{actions}}", with: actions)
            .replacingOccurrences(of: "{{siteJSON}}", with: Self.jsonString(site.value))
            .replacingOccurrences(of: "{{endsAt}}", with: endsAt.map(String.init) ?? "null")
            // Formatted here, like the app, rather than in the browser's own language.
            .replacingOccurrences(
                of: "{{until}}",
                with: Self.jsonString(snapshot?.endsAt?.formatted(.dateTime.hour().minute()) ?? "")
            )
            .replacingOccurrences(of: "{{isSummit}}", with: isSummit ? "true" : "false")
            .replacingOccurrences(of: "{{token}}", with: Self.jsonString(openToken))
            // Last, since the address comes from the tab and could hold a placeholder of its own.
            .replacingOccurrences(of: "{{returnJSON}}", with: returnAddress.map(Self.jsonString) ?? "null")
    }

    /// Stay on Your Path, and on a Trail a way to Tapa. Summit Mode offers no way out here, where
    /// the pull is strongest: a Descent needs Tapa opened on purpose.
    private var actions: String {
        let stay = #"<button type="button" class="primary" onclick="stay()">Stay on Your Path</button>"#
        guard !isSummit else { return stay }
        return stay + #"<button type="button" class="secondary" onclick="openTapa()">Open Tapa</button>"#
    }

    private static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// A JavaScript string literal. JSON's escaping is a safe subset, and `</` is broken up so the
    /// value can't close the script element.
    private static func jsonString(_ text: String) -> String {
        let encoded = (try? JSONEncoder().encode(text)).flatMap { String(bytes: $0, encoding: .utf8) } ?? "\"\""
        return encoded.replacingOccurrences(of: "</", with: "<\\/")
    }

    private static let template = """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Mist</title>
        <style>
        :root { color-scheme: light; }
        body { margin: 0; min-height: 100vh; background: #F1F5F8; color: #0E1A24;
          font-family: -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
          display: flex; flex-direction: column; align-items: center; justify-content: flex-end;
          padding: 40px 24px 12vh; box-sizing: border-box; overflow: hidden; }
        .photo { position: fixed; inset: 0 0 auto 0; height: 72vh; width: 100%; object-fit: cover;
          object-position: 50% 40%; -webkit-mask-image: linear-gradient(#000 50%, transparent);
          mask-image: linear-gradient(#000 50%, transparent); }
        main { position: relative; max-width: 640px; display: flex; flex-direction: column;
          align-items: center; gap: 16px; text-align: center; }
        h1 { margin: 0; font-family: ui-serif, "New York", Georgia, serif; font-size: 48px; line-height: 56px;
          font-weight: 500; letter-spacing: -0.01em; }
        p { margin: 0; font-size: 17px; line-height: 24px; color: #2E3E4C; }
        .actions { display: flex; flex-wrap: wrap; justify-content: center; gap: 12px; margin-top: 8px; }
        .primary, .secondary { display: inline-flex; align-items: center; gap: 8px; min-height: 44px;
          padding: 0 24px; border-radius: 22px; font: inherit; font-size: 15px; text-decoration: none;
          cursor: pointer; border: 0; }
        .primary { background: #13212E; color: #FFFFFF; font-weight: 600; }
        .secondary { background: rgba(255, 255, 255, 0.72); backdrop-filter: blur(16px);
          -webkit-backdrop-filter: blur(16px); box-shadow: 0 0 0 1px rgba(14, 26, 36, 0.1); color: #0E1A24; }
        </style>
        </head>
        <body>
        <img class="photo" src="/photo/{{photo}}.jpg" alt="">
        <main>
        <h1>{{line}}</h1>
        <p id="time"></p>
        <div class="actions">{{actions}}</div>
        </main>
        <script>
        const site = {{siteJSON}};
        const returnAddress = {{returnJSON}};
        const endsAt = {{endsAt}};
        const isSummit = {{isSummit}};

        function showTime() {
          if (!endsAt) return;
          const until = {{until}};
          const minutes = Math.max(1, Math.ceil((endsAt - Date.now()) / 60000));
          const left = minutes >= 60 ? Math.floor(minutes / 60) + "h " + (minutes % 60) + "m" : minutes + "m";
          document.getElementById("time").textContent = isSummit
            ? "You're in Summit Mode until " + until + ". The summit is " + left + " away."
            : "You're on the Trail until " + until + ", " + left + " to go.";
        }

        // The tracker opens Tapa, so the browser doesn't ask first.
        function openTapa() {
          fetch("/open?token=" + encodeURIComponent({{token}}), { method: "POST" });
        }

        // Back past the blocked page to where the tab was before it.
        function stay() {
          if (history.length > 2) history.go(-2);
          else location.replace("about:blank");
        }

        async function check() {
          try {
            const status = await (await fetch("/status?site=" + encodeURIComponent(site))).json();
            if (!status.blocked && returnAddress) location.replace(returnAddress);
          } catch {}
        }

        showTime();
        setInterval(showTime, 30000);
        setInterval(check, 1500);
        </script>
        </body>
        </html>
        """
}
