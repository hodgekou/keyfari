// SPDX-License-Identifier: GPL-3.0-only

import KeyfariCore
import Observation
import SwiftUI

/// What the user is typing into the label fields, before it is saved.
///
/// An observable object rather than view state, because the Command Line Tools ship without
/// the SwiftUI macro plugin that `@State` needs.
@MainActor
@Observable
final class StableLabelEditing {
    /// Unsaved text per entry.
    var drafts: [String: String] = [:]
    /// Why the last attempt to save was refused, already translated.
    var problem: String?
}

/// The remembered labels, grouped by application. Each label can be replaced or forgotten.
struct StableLabelsList: View {
    /// More rows than this would make the pane slow to open; the newest and the chosen ones are shown.
    private static let rowLimit = 150

    @Bindable var store: SettingsStore
    @Bindable var editing: StableLabelEditing
    let tint: Color

    var body: some View {
        let memory = store.labelMemory
        // Chosen labels first, then the ones used most recently.
        let ordered = memory.entries.sorted { lhs, rhs in
            lhs.isCustom == rhs.isCustom ? lhs.lastUsed > rhs.lastUsed : lhs.isCustom
        }
        let shown = Array(ordered.prefix(Self.rowLimit))
        let bundleIDs = shown.map(\.bundleID).reduce(into: [String]()) { result, id in
            if !result.contains(id) { result.append(id) }
        }

        VStack(alignment: .leading, spacing: 0) {
            Text(
                tr(
                    "When you click something by its label, Keyfari remembers that label and shows it again next time. Type other letters into a field and press Return to choose the label yourself."
                )
            )
            .font(.system(size: 11)).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12).padding(.vertical, 10)

            if let problem = editing.problem {
                Notice(problem, symbol: "exclamationmark.triangle.fill", tint: .orange)
            }

            if shown.isEmpty {
                RowDivider()
                Text(tr("No labels remembered yet"))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .padding(12)
            }
            ForEach(bundleIDs, id: \.self) { bundleID in
                RowDivider()
                let application = ApplicationInfo(bundleID: bundleID)
                HStack(spacing: 6) {
                    Image(nsImage: application.icon).resizable().frame(width: 16, height: 16)
                    Text(application.name).font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 4)
                ForEach(shown.filter { $0.bundleID == bundleID }) { entry in
                    row(entry)
                }
            }

            if !memory.entries.isEmpty {
                RowDivider()
                HStack {
                    if memory.entries.count > shown.count {
                        Text(tr("%d more labels are remembered", memory.entries.count - shown.count))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        memory.removeAll()
                        editing.drafts.removeAll()
                        editing.problem = nil
                    } label: {
                        Text(tr("Forget all labels"))
                    }
                    .buttonStyle(.bordered)
                }
                .padding(12)
            }
        }
    }

    private func row(_ entry: StableLabel) -> some View {
        let draft = Binding(
            get: { editing.drafts[entry.id] ?? entry.label },
            set: { editing.drafts[entry.id] = String(StableLabels.normalized(customLabel: $0).prefix(StableLabels.maximumCustomLength)) }
        )
        let isEdited = editing.drafts[entry.id].map { $0 != entry.label } ?? false
        return HStack(spacing: 10) {
            TextField("", text: draft)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .frame(width: 58)
                .onSubmit { save(entry) }
            Text(entry.title).font(.system(size: 12)).lineLimit(1)
            if entry.isCustom {
                StatusPill(text: tr("Chosen"), tint: tint)
            }
            Spacer(minLength: 4)
            if isEdited {
                Button(tr("Save")) { save(entry) }
                    .buttonStyle(.borderedProminent)
                    .tint(tint)
                    .controlSize(.small)
            }
            Button {
                store.labelMemory.remove(id: entry.id)
                editing.drafts[entry.id] = nil
            } label: {
                Image(systemName: "minus.circle.fill").foregroundStyle(.red.opacity(0.85))
            }
            .buttonStyle(.plain)
            .help(tr("Remove"))
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
    }

    private func save(_ entry: StableLabel) {
        let label = editing.drafts[entry.id] ?? entry.label
        guard label != entry.label else { return }
        let alphabet = store.effective.hintAlphabet
        switch store.labelMemory.setCustomLabel(label, id: entry.id, alphabet: alphabet) {
        case nil:
            editing.drafts[entry.id] = nil
            editing.problem = nil
        case .empty:
            // Nothing typed: back to the label it has.
            editing.drafts[entry.id] = nil
            editing.problem = nil
        case .tooLong, .notInAlphabet:
            editing.problem = tr("%@ is not saved: a label may only use your label characters, %@.", label, alphabet.uppercased())
        case let .conflicts(other):
            editing.problem = tr("%@ is not saved: it would clash with the label %@ chosen for another element of this application.", label, other)
        }
    }
}
