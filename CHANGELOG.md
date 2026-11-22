# Changelog

All notable changes to Keyfari are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Add opt-in local usage statistics for successful clicks, active days and frequently used apps.
- Add independent, off-by-default sounds for successful clicks and warning feedback.

### Removed

- Remove hold-Space activation and its settings, event interceptor and state machine.

## [0.1.1] - 2026-11-22

### Fixed

- Request Screen Recording access after Accessibility permission is granted when text detection is enabled.
- Keep activation gestures from consuming input in ignored applications or Keyfari's own settings.
- Keep link hint click points inside the visible part of clipped links.

## [0.1.0] - 2026-11-21

The first release.

### Added

- Hint mode: labels on every clickable element of the focused window, the menu bar, menu bar extras and notifications. Modifiers on the last letter select a right click, a double click, a command-click or moving the cursor only.
- Search mode: filter elements by their text, or by pinyin for Chinese text.
- Scroll mode: `h j k l`, half pages, top and bottom, and several scroll areas per window.
- On-screen text detection with Apple's Vision framework, on the device, for windows that expose little to the accessibility tree.
- Activation by customisable global shortcut, by holding `Space`, or by typing a key sequence.
- Click chains, stable labels, four label themes, ignored applications and launch at login.
- A settings window, and an interface in English, Chinese and Japanese.
