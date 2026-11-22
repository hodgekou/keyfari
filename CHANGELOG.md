# Changelog

All notable changes to Keyfari are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Hint mode labels every visible window on every display, not only the focused one. Windows on the display under the pointer share the short labels and appear together with the focused window; windows on other displays follow with longer labels that start with the last label character. A window in the background is brought forward before it is clicked. Text detection still reads the focused window only. The setting "Label all visible windows" switches this off.
- The Stable Labels pane lists the remembered labels by how often they were used, most used first, and shows the count.
- Keyfari checks once a day whether a newer version exists and offers to open its download page. A version can be skipped, and the check can be switched off in the General pane or from the offer itself. It is the only network request the app makes; nothing is downloaded and nothing about the user is sent. "Check for Updates…" in the menu checks at once.
- Search mode searches every visible window on every display too, after the focused window's elements, and brings a window in the background forward before clicking in it.
- The letters that scroll, and the two for half a page, can be changed in the Scrolling pane.

## [0.2.0] - 2026-11-22

### Added

- Add local usage statistics for successful clicks, active days and frequently used apps and an estimate of the time saved. They are on by default and can be switched off.
- Add independent, off-by-default sounds for successful clicks and warning feedback.
- Add a Liquid Glass hint theme on macOS 26 and later, with existing themes as the fallback on earlier systems.
- Add optional shortcuts that go one desktop (Space) to the left or right, acting on the display with the focused window.
- Add labels in Mission Control: the hint shortcut labels the windows and desktops of the overview, a typed label opens its item, on every display. An option shows the labels as soon as Mission Control opens.

### Changed

- Stable labels have their own settings pane. It lists the labels Keyfari remembered, and each can be replaced by one of your choice or forgotten.
- An element with text keeps its label when the window title or the surrounding layout changes; one without text, such as a toolbar icon, is recognised by its place in the window. Labels remembered by earlier versions are dropped.

### Removed

- Remove the Control-Option gesture for pinning a label; labels are chosen in the Stable Labels pane instead.
- Remove hold-Space activation and its settings, event interceptor and state machine.
- Remove activation by key sequence, together with the Activation settings pane.

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
