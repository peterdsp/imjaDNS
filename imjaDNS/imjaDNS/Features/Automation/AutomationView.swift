import SwiftUI
import ComposableArchitecture

struct AutomationView: View {
    @Bindable var store: StoreOf<AutomationFeature>

    var body: some View {
        List {
            Section {
                Toggle("Use a DNS on cellular data", isOn: Binding(
                    get: { store.cellularEnabled },
                    set: { store.send(.setCellularEnabled($0)) }
                ))
                if store.cellularEnabled {
                    Picker("Profile", selection: Binding(
                        get: { store.cellularProfileID },
                        set: { store.send(.setCellularProfile($0)) }
                    )) {
                        ForEach(store.profiles) { profile in
                            Text(profile.name).tag(UUID?.some(profile.id))
                        }
                    }
                }
            } header: {
                Text("Cellular data")
            } footer: {
                Text("When on, iOS automatically applies this DNS on mobile data and turns it off on Wi-Fi — enforced by the system in the background, even when imjaDNS is closed.")
            }

            Section {
                if store.rules.isEmpty {
                    Text("No automation rules yet. Add one to switch DNS automatically based on your network or the time of day.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.rules) { rule in
                        ruleRow(rule)
                    }
                }
            } header: {
                Text("Rules")
            } footer: {
                Text("Rules are checked top to bottom — the first match wins. Automation runs while the app is active and on next launch.")
            }

            Section {
                Button {
                    store.send(.addRuleTapped)
                } label: {
                    Label("Add Rule", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("Automation")
        .onAppear { store.send(.onAppear) }
        .sheet(isPresented: Binding(
            get: { store.isAddingRule },
            set: { if !$0 { store.send(.cancelDraft) } }
        )) {
            draftForm
        }
    }

    private func ruleRow(_ rule: AutomationRule) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.trigger.summary).font(.subheadline.weight(.medium))
                Text("→ \(store.profileName(for: rule.profileID))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in store.send(.toggleRule(rule.id)) }
            ))
            .labelsHidden()
        }
        .swipeActions {
            Button(role: .destructive) {
                store.send(.deleteRule(rule.id))
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Add rule sheet

    private var draftForm: some View {
        NavigationStack {
            Form {
                Section("When") {
                    Picker("Trigger", selection: $store.draft.kind) {
                        ForEach(AutomationFeature.State.TriggerKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }

                    switch store.draft.kind {
                    case .ssid:
                        TextField("Wi-Fi name (SSID)", text: $store.draft.ssid)
                            .textInputAutocapitalization(.never)
                    case .schedule:
                        DatePicker("From", selection: minuteBinding($store.draft.startMinute), displayedComponents: .hourAndMinute)
                        DatePicker("To", selection: minuteBinding($store.draft.endMinute), displayedComponents: .hourAndMinute)
                    case .anyWifi, .cellular:
                        EmptyView()
                    }
                }

                Section("Apply") {
                    Picker("Profile", selection: $store.draft.profileID) {
                        Text("Disable DNS").tag(UUID?.none)
                        ForEach(store.profiles) { profile in
                            Text(profile.name).tag(UUID?.some(profile.id))
                        }
                    }
                }
            }
            .navigationTitle("New Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.cancelDraft) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.send(.saveDraft) }
                        .disabled(!store.draft.isValid)
                }
            }
        }
    }

    /// Bridges a "minutes from midnight" Int binding to a Date for `DatePicker`.
    private func minuteBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: minutes.wrappedValue / 60,
                                      minute: minutes.wrappedValue % 60,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            }
        )
    }
}
