<div align="center">

<img src="Xboard/Assets.xcassets/AppIcon.appiconset/icon-128.png" alt="Xboard icon" width="80" height="80" />

# Xboard

### Keep your flow. Find what you copied.

A native clipboard manager built for macOS.<br />
Press **⌥V** to bring back text, images, and files, then get on with your work.

**Free to use** · **Locally encrypted** · **English / Traditional Chinese** · **MIT licensed**

[Get started](#quick-start)　·　[Explore features](#features)　·　[Privacy](#privacy)　·　[FAQ](#faq)

</div>

<p align="center">
  <img src="docs/assets/xboard-hero.svg" alt="Xboard product illustration: open the panel with ⌥V, search, and select something you copied earlier." width="1280" />
</p>

<p align="center"><sub>Product illustration with fictional content. Actual appearance varies with your macOS version and settings.</sub></p>

## From “where did I copy that?” to your next step.

A draft you were writing, a link from your research, an image for your presentation: Xboard keeps them within reach. Spend less time reopening pages and more time on what you wanted to finish.

| **01　Copy as usual** | **02　Press ⌥V** | **03　Select and paste** |
| :--- | :--- | :--- |
| Keep using ⌘C. Xboard saves your clipboard history in the background. | Search by keyword or filter by type, source app, and date. | Select with ↑↓, press Return to paste into the previous app, or Esc to close. |

<sub>Automatic paste requires macOS Accessibility permission. Without it, select an item and paste manually with ⌘V.</sub>

<a id="features"></a>

## Easier to find than to remember.

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>One shortcut to pick up where you left off</h3>
      <p>Open a compact panel with ⌥V and search as you type. Text, images, GIFs, and file references share one history.</p>
    </td>
    <td width="50%" valign="top">
      <h3>Keep everyday content close</h3>
      <p>Pin as many items as you need. Pinned items stay outside history limits and retention cleanup, so common replies, code snippets, and work materials remain handy.</p>
    </td>
  </tr>
  <tr>
    <td valign="top">
      <h3>From search to paste, all by keyboard</h3>
      <p>Use the arrow keys to select, Return to paste, and ⌘1–⌘9 to choose visible items. Paste as plain text, create Markdown links, or format JSON.</p>
    </td>
    <td valign="top">
      <h3>Find the words inside images</h3>
      <p>Recognize text in static images locally, include it in search, or extract and copy it. Your images never need to go to a cloud service for OCR.</p>
    </td>
  </tr>
  <tr>
    <td valign="top">
      <h3>At home on your Mac</h3>
      <p>A native SwiftUI and AppKit interface with light and dark appearances. The interface follows your macOS language preferences, with English and Traditional Chinese support. Customize shortcuts, history limits, and launch at login.</p>
    </td>
    <td valign="top">
      <h3>You decide what stays</h3>
      <p>Keep the latest 200 unpinned items by default, adjust the count and retention period, pause capture, exclude apps, or skip the next copy.</p>
    </td>
  </tr>
</table>

### Less repetition in your everyday work.

| Your work | What Xboard keeps within reach |
| :--- | :--- |
| **Writing and communication** | Recover draft versions and recent quotes, or save common replies in the text Library. |
| **Development and debugging** | Reuse code and links, format valid JSON, and paste a sequence of copied items in order. |
| **Design and research** | Preview images, search text in screenshots, and find reference material from different apps. |
| **Data and documents** | Narrow results by source, date, and type to find the item you need. |

<details>
<summary><strong>More useful features under “More tools”</strong></summary>

- **Text Library**: Save titles, content, collections, and tags separately from history cleanup.
- **Clipboard Stack**: Queue items in copy order and paste them one at a time.
- **Quick Look**: Preview text, images, GIFs, and accessible original files.
- **Screenshot annotation**: Highlight details with freehand drawing, arrows, and rectangles.
- **GIF recording**: Select a screen area and create a short GIF locally.

These tools live in the menu. Only the ⌥V global shortcut is enabled by default. Screenshot and recording features may require macOS Screen Recording permission.

</details>

<a id="privacy"></a>

## Your clipboard stays on your Mac.

You should know how your copied content is stored. Xboard needs no account, subscription, or backend service, and includes no advertising or analytics tracking code.

| Design | What it means for you |
| :--- | :--- |
| **AES-GCM local encryption** | History and Library content are encrypted on disk. The key stays in this Mac's login Keychain. |
| **Local processing** | Search, OCR, and content formatting run locally. There is no cloud sync or content upload workflow. |
| **Control over capture** | Exclude apps, pause history, skip the next copy, and ignore content marked as sensitive or transient. |
| **Cleanup preserves original files** | File history stores references. Clearing history does not delete original files or clear the system clipboard. |

<sub>Unmarked sensitive text may still enter history. Exclude the relevant app or pause capture in Settings. See the [security notes](SECURITY.md).</sub>

<a id="quick-start"></a>

## Make your next copy more useful.

### Build from source

| | Requirement |
| :--- | :--- |
| **Runtime** | macOS 14 or later. Universal builds include Apple Silicon and Intel. |
| **Build tools** | Xcode 26 or later with the macOS 26 SDK. |
| **Source** | Clone from GitHub and build locally. |

```sh
git clone https://github.com/timmyc07/Xboard.git
cd Xboard
./scripts/build-app.sh
open build/Xboard.app
```

You can also open `Xboard.xcodeproj` in Xcode and select **Xboard → My Mac** to build and run.

**Source code and a local build script are currently available; an Apple-notarized installer has not been released.** The script produces `build/Xboard.app` and `build/Xboard.zip` with ad-hoc signing.

### Three steps for your first launch

1. **Open Xboard**: Allow clipboard and Keychain access when macOS prompts so your history can be saved with encryption.
2. **Enable automatic paste**: Click “Enable automatic paste…” in the panel, then enable Xboard under **System Settings → Privacy & Security → Accessibility**.
3. **Copy something and press ⌥V**: Search, select, and return to your work.

<sub>All settings are in the app; no `.env` file is required. Replacing a local build may cause macOS to request Keychain or Accessibility permission again.</sub>

### Interface language

Xboard follows your macOS preferred language order. It supports **English** and **Traditional Chinese**, with English as the fallback when none of your preferred languages is supported. Regional preferences such as English (US) and Traditional Chinese (Taiwan) select the corresponding language automatically.

Change your preferences in **System Settings → General → Language & Region**, then quit and reopen Xboard. A macOS per-app language preference for Xboard takes precedence over the system language order.

<a id="faq"></a>

## A few things to know

<details>
<summary><strong>Does it really need no subscription?</strong></summary>

Yes. Xboard is free to use and MIT licensed, with no account, paid SDK, or server dependency. Building it yourself requires Xcode.

</details>

<details>
<summary><strong>Why does history work, but selecting an item does not paste automatically?</strong></summary>

Clipboard capture and sending ⌘V automatically require different permissions. Enable Xboard under Accessibility; the panel also provides a direct link. Without permission, selecting an item still restores it to the clipboard, so you can switch to the destination app and press ⌘V manually.

Automatic paste and caret positioning also depend on the destination app's focus and Accessibility support.

</details>

<details>
<summary><strong>Can I change the shortcut and history limit?</strong></summary>

Yes. The default shortcut is ⌥V, and the default limit is 200 unpinned items. You can enter any count of 10 or more. Pinned items do not count toward the limit. Large image histories use more memory and disk space, so choose a limit that suits your work.

⌥V replaces the special character normally entered by that key combination. Change it in Settings if it conflicts with your input method. Secure password fields may block this kind of shortcut.

</details>

<details>
<summary><strong>Where is my content stored? Does it sync between devices?</strong></summary>

History and Library content are stored in `~/Library/Application Support/Xboard/` with AES-GCM encryption. The key stays in the local Keychain and does not sync through iCloud. Cross-device sync is not currently available. Deleting the Keychain key makes existing records unreadable.

File records reference the originals. Moving or deleting those files, or losing access to them, may make the references unusable.

</details>

---

## Native, from interface to implementation.

**Swift · SwiftUI · AppKit · CryptoKit · Vision**

Xboard uses Apple platform frameworks with no third-party runtime packages. macOS 26 supports native Liquid Glass; earlier versions use standard translucent materials.

<details>
<summary><strong>For developers: build, architecture, and validation</strong></summary>

The project uses Swift 5 language mode. Run the tests with:

```sh
xcodebuild -project Xboard.xcodeproj -scheme Xboard \
  -destination 'platform=macOS' -derivedDataPath build/DerivedData test
```

- [Implementation and data flow](docs/implementation.md)
- [Open-source research and technical decisions](docs/research.md) (Traditional Chinese)
- [Validation results and environments still to verify](docs/validation.md) (Traditional Chinese)
- [Contributing](CONTRIBUTING.md)

Local Universal builds have been completed. Runtime checks on Intel and macOS 14–25, cross-app automatic paste, and long-running resource use still need further testing on real hardware.

</details>

### License and acknowledgments

Xboard is derived from the MIT-licensed [Kelsiito/clipboard](https://github.com/Kelsiito/clipboard), retaining the original Git history, license, and app icon. The product hero is an illustration created for Xboard. See [LICENSE](LICENSE) and [third-party notices](THIRD_PARTY_NOTICES.md). Historical upstream documents are preserved in `docs-upstream/`.

<div align="center">

**Keep what you copied for the next time you need it.**

[Get started with Xboard ↑](#quick-start)

</div>
