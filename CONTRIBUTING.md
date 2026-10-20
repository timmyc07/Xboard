# Contributing to Xboard

Use native Apple frameworks and keep all clipboard data local. Product settings belong in the app; no `.env` is required.

Run the XCTest suite and a Release build for changes affecting capture, encryption, retention, hotkeys, or paste behavior. Use synthetic fixtures only. Never commit clipboard data, signing credentials, private screenshots, keys, certificates, or generated builds.

For UI changes, check Traditional Chinese and English, search/arrow/Return/Esc navigation, and both granted and denied Accessibility states. Verify that pinned items survive capture, lowering the history limit, retention cleanup, and relaunch.

Keep upstream MIT notices. Update Localizable.xcstrings for user-visible strings. See docs/implementation.md for architecture and distribution limits.
