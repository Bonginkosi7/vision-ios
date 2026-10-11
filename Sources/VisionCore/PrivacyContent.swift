import Foundation

/// The privacy screen’s wording — generated from desktop’s src/shared/privacyContent.ts so all three apps say the same thing.
public struct PrivacyItem: Equatable {
    public let title: String
    public let text: String
}

public struct PrivacySection: Equatable {
    public let id: String
    public let heading: String
    public let intro: String?
    public let items: [PrivacyItem]
}

public enum PrivacyContent {
    public static let contactEmail = "hello@ann-connect.com"
    public static let policyURL = "https://www.ann-connect.com/trust"

    public static let sections: [PrivacySection] = [
        PrivacySection(id: "stays", heading: "What stays on this device", intro: "VISION keeps all of this on your own device. It is never uploaded.", items: [
            PrivacyItem(title: "Your browsing", text: "History, bookmarks, tabs, your list of downloads, and the pages you save for offline use."),
            PrivacyItem(title: "Passwords", text: "Saved logins are kept encrypted with your device's secure storage, and only filled into the site they belong to."),
            PrivacyItem(title: "Your notes and study", text: "Tasks, VISION Memory, study materials and documents you add, flashcards, exams and your study plan."),
            PrivacyItem(title: "Your chats", text: "Your Ask VISION conversations and anything you attach to them."),
            PrivacyItem(title: "Your profile and rewards", text: "Your name, photo and country, your settings, and your points and activity."),
        ]),
        PrivacySection(id: "leaves", heading: "What leaves this device, and when", intro: "Only when you use the feature that needs it.", items: [
            PrivacyItem(title: "Websites and search", text: "Pages load straight from the sites you visit, like any browser. Your search engine gets what you search for."),
            PrivacyItem(title: "Ask VISION and other AI features", text: "If you use your own OpenAI or Anthropic key, your question goes to that provider. With VISION AI, your question goes to VISION's service, which passes it to OpenAI and keeps only a daily question count for your device — not what you asked. The offline model runs entirely on your device."),
            PrivacyItem(title: "Translate page", text: "Only when you choose it on a page: the page's address is sent to Google Translate, which fetches and translates that page. Nothing is sent otherwise."),
            PrivacyItem(title: "Headlines and weather", text: "Headlines come from BBC News. Weather, if you switch it on and allow your location, sends your coordinates to Open-Meteo and BigDataCloud to get conditions and a place name."),
            PrivacyItem(title: "Rewards and Redeem", text: "VISION uses an anonymous account to read the reward catalogue. If you redeem a reward, the request — the reward, its points cost and, for airtime, your mobile number — is sent to Ann-Connect so it can be fulfilled."),
            PrivacyItem(title: "Anonymous usage statistics", text: "On by default and switchable below. Counts of which features are used, tied to a random code made on your device — never the pages you visit, your searches or anything you type. Crash reports are a separate switch."),
            PrivacyItem(title: "A licence key", text: "Only if your organisation gives you one. VISION checks the key with the licence server and reports how many offline syncs this device did each day, so your organisation can be billed."),
        ]),
        PrivacySection(id: "never", heading: "What VISION never does", intro: nil, items: [
            PrivacyItem(title: "Sells or shares your data", text: "VISION does not sell your data or use it for advertising."),
            PrivacyItem(title: "Collects your browsing", text: "VISION never sends your history, the addresses you visit or page contents to Ann-Connect."),
        ]),
    ]

    public enum Rights {
        public static let exportTitle = "Download my data"
        public static let exportText = "Saves a file with your bookmarks, history, tasks, memory, chats, rewards, profile and settings. Saved passwords are left out on purpose, and so are the saved pages themselves."
        public static let deleteTitle = "Delete my data"
        public static let deleteText = "Erases everything VISION holds on this device — history, bookmarks, passwords, chats, study material, offline pages, rewards and your profile — and asks VISION's servers to delete the usage statistics and crash reports tied to this device, and to free its licence place. VISION then starts fresh."
        public static let deleteLimits = "Not covered: files you saved outside VISION (for example in your computer's Downloads folder), and rewards you already redeemed — those requests are kept by Ann-Connect so they can be fulfilled and audited. To have them removed, email hello@ann-connect.com."
        public static let confirmTitle = "Delete all your VISION data?"
        public static let confirmDetail = "This can't be undone. VISION will erase everything on this device and start fresh."
    }
}
