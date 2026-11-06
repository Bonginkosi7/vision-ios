# VISION for iPhone — App Store pack

Everything to fill in App Store Connect, written from what the app actually does. **CHECK** marks anything a person must
confirm. Nothing here is legal advice.

## 1. One-time setup (you, on the web)

1. **Register the bundle ID.** developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → + → App IDs →
   App → description "VISION", Bundle ID **Explicit**: `com.vision.browser`. If Apple says it is not available (a free
   personal team may have reserved it earlier), tell me: the fix is a new bundle ID such as `net.visionbrowser.app`.
2. **Create the app.** appstoreconnect.apple.com → Apps → + → New App: platform iOS, name below, primary language English
   (South Africa), bundle ID `com.vision.browser`, SKU `vision-ios`, full access.
3. **Create an API key.** App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys → +,
   name "GitHub builds", access **App Manager**. Note the **Key ID** and the **Issuer ID**, and download the `.p8` file
   (it can only be downloaded once). Keep it private.
4. **Find the Team ID:** developer.apple.com → Membership details → Team ID (10 characters).
5. **Add these secrets** to the `vision-ios` GitHub repo (Settings → Secrets and variables → Actions). Type them in
   yourself; never paste them into a chat:
   `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_KEY_P8_BASE64` (in Terminal: `base64 -i ~/Downloads/AuthKey_XXXX.p8 | pbcopy`
   then paste). The app settings secrets are also read: `VISION_AI_PROXY_URL`, `VISION_AI_PROXY_KEY`,
   `VISION_FIREBASE_API_KEY`, `VISION_FIREBASE_PROJECT_ID`, `VISION_ANALYTICS_URL`, `VISION_ANALYTICS_WRITE_KEY`,
   `VISION_LICENCE_PUBLIC_KEY`.
6. **Build and upload.** GitHub → vision-ios → Actions → **iOS App Store build** → Run workflow. It builds with the newest
   Xcode on a GitHub Mac (Apple only accepts Xcode 26 or later; this Mac cannot run it), signs in the cloud and uploads.
   Turn "upload" off first to check that signing works. The build then shows in App Store Connect → TestFlight after
   Apple's processing (about 10 to 30 minutes).

## 2. Version
Use **1.0.0** for the first public release (the workflow's default). The build number is set automatically for every
run, so each upload is accepted.

## 3. App information
* **Name (max 30):** VISION Browser
* **Subtitle (max 30):** Offline browser with AI help
* **Primary category:** Utilities (where browsers are listed). **Secondary:** Productivity.
* **Support URL:** https://vision-browser.net/support — **Marketing URL:** https://vision-browser.net
* **Privacy policy URL:** https://vision-browser.net/privacy
* **Copyright:** 2026 Ann-Connect Technologies
* **Price:** Free. **Devices:** iPhone only (iPad is switched off for version 1).

**Promotional text (max 170):**
```
Browse the web, save pages for offline, and ask questions with or without internet. Study tools, focus mode and rewards, made in South Africa.
```

**Keywords (max 100 characters, comma-separated):**
```
offline,browser,AI,study,flashcards,focus,private,reader,translate,saved pages,ask,learn
```

**Description (max 4000):**
```
VISION is a browser that keeps working when your connection doesn't.

Browse the web with tabs, split view, pinned tabs, bookmarks, private browsing, reader view and page translation. Save the pages you need for offline use and open them any time, with no signal.

ASK VISION
Ask questions, plan, explain and draft. When you're online, VISION AI answers. When you're not, an offline model that you download once (about 1.1 GB) answers on your iPhone. Offline answers come from a smaller model and can be wrong, so check important facts when you're online.

STUDY TOOLS
Add your own material, then use flashcards, mock exams, an AI tutor, a study plan and paper review.

FOCUS AND WELLBEING
Start a focus session that blocks the sites you choose, and get reminders to take healthy breaks.

VISION POINTS AND REWARDS
Earn points for saving pages, taking breaks, finishing study sessions and focus sessions, then redeem them for rewards.

YOUR DATA STAYS WITH YOU
Your history, bookmarks, passwords, notes and chats stay on your iPhone. VISION never sends the pages you visit to its servers, never sells your data and shows no ads. Anonymous usage statistics are on by default and can be switched off in Settings, and Settings can delete everything VISION holds.

VISION is built by Ann-Connect in South Africa.
```

**What's New (first version):** `First release of VISION for iPhone.`

## 4. Review information
* **Sign-in required:** No. No demo account is needed.
* **Notes for the reviewer:**
```
VISION is a web browser built on WKWebView (Apple's WebKit). No account or login is needed. Ask VISION sends questions to Ann-Connect's own service when the device is online; an optional offline model (about 1.1 GB, model weights only, no executable code) can be downloaded from the home page. Location is requested only if the user turns on the home-page weather. Camera and microphone are requested only when a website asks, per site, with a prompt. Contact: hello@ann-connect.com
```
* **Contact:** your name, phone and email (Apple uses them only for review questions).

## 5. Age rating
Answer the questionnaire honestly. VISION is a browser with unrestricted web access, which the questionnaire counts, and
Apple may raise the rating for that. No violence, sexual content, gambling or contests are made by the app itself.

## 6. App Privacy ("nutrition label") — draft from the app's behaviour
**Data used to track you: none.** There are no ads, no advertising ID and no cross-app tracking, so no tracking prompt.
"Collected" means leaving the device and kept longer than needed to answer a request.

| Apple data type | Collected? | Linked to the user? | Purpose |
|---|---|---|---|
| Contact info → Phone number | Only when redeeming airtime or data | Yes (the redemption) | App functionality |
| Identifiers → Device ID (random install code) | Yes | No | App functionality, analytics |
| Usage data → Product interaction (feature-use counts) | Yes, optional switch | No | Analytics |
| Diagnostics → Crash data | Yes, optional switch | No | Analytics, app functionality |
| User content → Other user content (questions to VISION AI) | Sent to VISION's service and passed to OpenAI; only a daily count is kept | No | App functionality |
| Location → Coarse location | Sent to the weather services when weather is on; not kept by VISION | No | App functionality |

**CHECK** every row with whoever is responsible for privacy. These answers are a declaration to Apple.

## 7. Screenshots
App Store Connect needs 1 to 10 screenshots for the largest iPhone size (6.9-inch, 1320 × 2868; the 6.5-inch set is also
accepted). They should show the real app. They will be generated on a cloud simulator by the UI tests and attached to a
release for download; ask for them when the first build is in TestFlight.

## 8. Before pressing "Submit for Review"
* Install the TestFlight build on your iPhone and walk through it (browse, Ask VISION, Redeem, Settings → Delete my data).
* Make sure vision-browser.net/privacy and /delete-data are live.
* Every answer above matches the in-app Privacy & data screen.
