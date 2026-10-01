import Foundation

struct HelpCard {
    let title: String
    let body: String
}

struct HelpSection {
    let label: String
    let cards: [HelpCard]
}

/// Real in-app documentation — the iOS counterpart of desktop's Help
/// Center and Android's own HelpContent.kt. Not a literal translation of
/// either: this describes only what's actually real and built on iOS
/// right now (as of Phase 14) — no Redeem, no Ask VISION chat, no
/// on-device model fallback, no Android's separate Study Material hub,
/// since none of those exist here yet. Describing them would be exactly
/// the kind of fabricated-capability claim this app avoids everywhere
/// else, so this is a genuine rewrite for this platform's own real
/// feature set, not a copy-paste.
let helpSections: [HelpSection] = [
    HelpSection(label: "Downloads & Offline", cards: [
        HelpCard(
            title: "Saving a page for offline",
            body: "Open the ⋮ menu while on a page and tap \"Save Offline\" to save a real, complete local copy — viewable afterward in Offline Library with no connection at all."
        ),
        HelpCard(
            title: "Downloading files",
            body: "Tap a file link and it downloads through the browser's own real download handling — visible afterward in ⋮ menu → Downloads."
        ),
    ]),
    HelpSection(label: "Focus Mode", cards: [
        HelpCard(
            title: "Blocking sites for a session",
            body: "⋮ menu → Focus Mode: add domains to your own block list, pick a duration, and VISION blocks them until the session ends or you stop it early."
        ),
    ]),
    HelpSection(label: "VISION Education", cards: [
        HelpCard(
            title: "My Materials & Topics",
            body: "Upload a PDF, DOCX, or TXT file — VISION reads the real text on-device, no AI involved. Tap \"Topics\" on a processed document for a real AI-identified outline of what it actually covers."
        ),
        HelpCard(
            title: "Paper Review, Rewrite Writer, Flashcards, Exams, AI Tutor",
            body: "All grounded in your own uploaded material and your own OpenAI or Anthropic API key (added in Settings). With no key configured, each of these tells you so honestly instead of making something up."
        ),
        HelpCard(
            title: "Performance",
            body: "A real per-topic mastery dashboard, built only from your own flashcard reviews and marked exam answers — a topic shows \"Not yet assessed\" until there's genuinely enough real data to say more."
        ),
        HelpCard(
            title: "My Week",
            body: "A deterministic weekly study plan built from your real topic mastery — no AI call involved. Weaker topics get more sessions automatically. Tapping \"Start session\" on a plan item opens real Flashcards or a real generated mock test, and tracks it as a real study session."
        ),
    ]),
    HelpSection(label: "Wellbeing & Rewards", cards: [
        HelpCard(
            title: "VISION Advisor",
            body: "A local, rule-based advisor that suggests a break once your continuous session crosses a real time threshold. No health claims — just a nudge based on your own real activity."
        ),
        HelpCard(
            title: "VISION Points",
            body: "A real ledger. Points come only from real actions — a healthy break, saving something offline, completing a task, a mock test, a study-plan session — never a fabricated bonus."
        ),
        HelpCard(
            title: "Tasks",
            body: "A simple real task list. Completing a task is one-way and earns real points exactly once — unchecking and rechecking can't be used to farm rewards."
        ),
    ]),
    HelpSection(label: "Privacy", cards: [
        HelpCard(
            title: "What VISION iOS does and doesn't collect",
            body: "Your history, bookmarks, downloads, and saved pages stay on this device. VISION iOS doesn't send usage analytics anywhere — that's simply not built, not a setting you have to find and turn off."
        ),
        HelpCard(
            title: "Private Browsing",
            body: "⋮ menu → New Private Tab opens a real, separately isolated session — its own storage, no history recorded — and is wiped when you close it."
        ),
    ]),
]
