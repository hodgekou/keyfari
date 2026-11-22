# Contributing to Keyfari

Bug reports, fixes and translations are welcome. Open an issue first for anything larger than a small fix, so the approach can be agreed before you spend time on it.

## Getting started

You need macOS 14 or later and a Swift 6 toolchain. The Command Line Tools are enough.

```sh
scripts/bundle.sh          # build build/Keyfari.app
scripts/test.sh            # run the unit tests
scripts/lint.sh            # check formatting and style
scripts/check-repo.sh      # check licence headers, translations, documented paths and versions
```

`scripts/test.sh` exists because the Command Line Tools keep the Swift Testing macro plugin outside the compiler's default search path. With Xcode installed, plain `swift test` works too.

## Before you open a pull request

- `scripts/test.sh`, `scripts/lint.sh` and `scripts/check-repo.sh` pass. CI runs all three.
- The build has no warnings. CI builds with warnings as errors: `swift build -Xswiftc -warnings-as-errors`.
- New logic in `KeyfariCore` comes with unit tests.
- Changes to accessibility, input handling or the overlay are tried in a real application. These parts need system permissions and have no automated tests, so say in the pull request what you tried and in which application.

## What CI checks

Every pull request runs four jobs:

- **Build and test**: the package builds without warnings and the unit tests pass.
- **Lint and repository checks**: `scripts/lint.sh` and `scripts/check-repo.sh`.
- **Package the app**: a universal release build is assembled, signed ad hoc and packed into a disk image. The image is kept with the run for a week, so a change can be tried without building it.
- **Check shell scripts**: ShellCheck on `scripts/*.sh`.

## Conventions

- **Swift 6 language mode** with strict concurrency. UI and mode state live on the main actor; accessibility calls are blocking cross-process requests and never run on the main thread.
- **Formatting** follows `.swift-format`: four spaces, 150 columns. `scripts/lint.sh --fix` applies it.
- **No force unwraps**, no force `try`, no implicitly unwrapped optionals. The linter enforces this.
- **Dependencies point one way**: `KeyfariApp` depends on the kits, the kits depend on `KeyfariCore`, and the kits do not depend on each other. Anything that can be decided without calling the system belongs in `KeyfariCore`, where it can be tested.
- **Comments say why**, not what. Leave a comment where a reader would otherwise have to guess: a workaround, a constraint, a non-obvious choice.
- **One third-party dependency**: [Sparkle](https://sparkle-project.org), which installs updates. It ships as a prebuilt framework that the package manager downloads and `scripts/bundle.sh` puts into the app. Raise an issue before adding another.
- **Every source file starts with** `// SPDX-License-Identifier: GPL-3.0-only`. Code adapted from Vimac keeps the note naming the original file and author.

## Adding or fixing a translation

Interface text lives in `Sources/KeyfariCore/Settings/Localization.swift`. The English text is the key; each entry carries the Chinese and Japanese text. Use `tr("English text")` in the app, and add an entry to the table. A unit test checks that every entry is translated and keeps its `%d` / `%@` placeholders.

To add a language, add a case to `Language` and `AppLanguage`, a field to `Localizer.Entry`, and its text to every entry.

## Debugging aids

Debug builds only:

- `pkill -USR1 -x Keyfari` toggles hint mode and `pkill -USR2 -x Keyfari` toggles scroll mode, so a mode can be driven from a terminal. A release build ignores both signals.
- `Keyfari --open-settings` opens the settings window at launch, and `Keyfari --open-welcome` the welcome guide.
- `Keyfari --render-settings <directory>` writes a PNG of every settings pane and every step of the welcome guide in every language and exits. It uses a throwaway defaults domain, so it neither reads nor changes your settings.

Logs go to the unified log:

```sh
log stream --predicate 'subsystem == "app.keyfari.Keyfari"'
```

## The icon

`Resources/AppIcon.icns` is drawn by code:

```sh
swift scripts/make-icon.swift /tmp/AppIcon.iconset
iconutil -c icns /tmp/AppIcon.iconset -o Resources/AppIcon.icns
```

## Releasing

1. Add a section for the new version to `CHANGELOG.md`, set the same version in `Resources/Info.plist`, and get both onto `main`. `scripts/check-repo.sh` fails when the two disagree.
2. Tag that commit and push the tag: `git tag v0.2.0 && git push origin v0.2.0`.

The `Release` workflow first checks that the tag has a section in the changelog, then builds a universal app, signs the update and adds it to the update feed, packs it into a disk image, publishes a GitHub release with that section as its notes, and points `Casks/keyfari.rb` at the new image.

### The update key

Installed copies only accept an update that is signed with the project's EdDSA key. The public half is `SUPublicEDKey` in `Resources/Info.plist`; the private half is the repository secret `SPARKLE_PRIVATE_KEY` and must never be committed. The workflow signs each disk image and `scripts/update-appcast.py` adds it to `site/appcast.xml`, the feed the app reads from the project's site.

A build whose `Info.plist` has no public key cannot verify updates, so it only announces a new version and opens its download page.

To set the key up once, as a maintainer:

```sh
swift build                                               # downloads Sparkle and its tools
.build/artifacts/sparkle/Sparkle/bin/generate_keys        # creates the key in your keychain and prints the public half
.build/artifacts/sparkle/Sparkle/bin/generate_keys -x sparkle-private-key.txt   # exports the private half
```

Put the public key into `Resources/Info.plist`, store the contents of the exported file as the secret `SPARKLE_PRIVATE_KEY`, and delete the file.

## Licence

By contributing you agree that your contribution is licensed under GPL-3.0, like the rest of the project.
