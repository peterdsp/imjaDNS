import SwiftUI
import ComposableArchitecture

struct SitesView: View {
    @Bindable var store: StoreOf<SitesFeature>

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                searchField
                categoryChips
                checkAllButton
                LazyVStack(spacing: 10) {
                    ForEach(store.visibleSites) { siteRow($0) }
                }
                if store.visibleSites.isEmpty {
                    Text("No sites match. Add one with +.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background { AnimatedMeshBackground() }
        .navigationTitle("Site Check")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.send(.setShowAddSheet(true)) } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear { store.send(.onAppear) }
        .sheet(isPresented: Binding(
            get: { store.showAddSheet },
            set: { store.send(.setShowAddSheet($0)) }
        )) { addSheet }
    }

    // MARK: - Search & filters

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search sites", text: Binding(
                get: { store.searchText },
                set: { store.send(.searchChanged($0)) }
            ))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            if !store.searchText.isEmpty {
                Button { store.send(.searchChanged("")) } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "Favorites", icon: "star.fill", active: store.favoritesOnly) {
                    store.send(.favoritesOnlyToggled(!store.favoritesOnly))
                }
                chip(title: "All", icon: "square.grid.2x2", active: store.selectedCategory == nil && !store.favoritesOnly) {
                    store.send(.favoritesOnlyToggled(false))
                    store.send(.categorySelected(nil))
                }
                ForEach(SiteCategory.allCases) { cat in
                    chip(title: cat.title, icon: cat.icon, active: store.selectedCategory == cat) {
                        store.send(.categorySelected(store.selectedCategory == cat ? nil : cat))
                    }
                }
            }
        }
    }

    private func chip(title: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption2)
                Text(LocalizedStringKey(title)).font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(active ? AnyShapeStyle(AppTheme.accentGradient) : AnyShapeStyle(Material.ultraThin), in: Capsule())
            .foregroundStyle(active ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private var checkAllButton: some View {
        Button { store.send(.checkVisible) } label: {
            HStack(spacing: 8) {
                if store.isCheckingAll {
                    ProgressView().controlSize(.mini).tint(.white)
                } else {
                    Image(systemName: "bolt.horizontal.circle")
                }
                Text(store.isCheckingAll ? "Checking…" : "Check all shown")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(AppTheme.accentGradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius, style: .continuous))
        }
        .disabled(store.isCheckingAll)
    }

    // MARK: - Rows

    private func siteRow(_ site: Website) -> some View {
        let result = store.results[site.domain]
        return GlassCard {
            HStack(spacing: 12) {
                Image(systemName: site.category.icon)
                    .font(.body)
                    .foregroundStyle(AppTheme.accentGradient)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(site.name).font(.subheadline.weight(.semibold))
                    Text(resultDetail(result) ?? site.domain)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button { store.send(.toggleFavorite(site.domain)) } label: {
                    Image(systemName: store.favoriteDomains.contains(site.domain) ? "star.fill" : "star")
                        .foregroundStyle(store.favoriteDomains.contains(site.domain) ? Color(hex: "F2C94C") : .secondary)
                }
                .buttonStyle(.plain)

                checkControl(site: site, result: result)
            }
        }
        .contextMenu {
            if site.isCustom {
                Button(role: .destructive) { store.send(.deleteCustom(site.domain)) } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func checkControl(site: Website, result: SiteCheckResult?) -> some View {
        if result?.phase == .checking {
            ProgressView().controlSize(.small)
        } else if let result, result.phase == .done {
            Button { store.send(.checkSite(site)) } label: {
                Text(LocalizedStringKey(verdictLabel(result.verdict)))
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(verdictColor(result.verdict).opacity(0.16), in: Capsule())
                    .foregroundStyle(verdictColor(result.verdict))
            }
            .buttonStyle(.plain)
        } else {
            Button { store.send(.checkSite(site)) } label: {
                Text("Check")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func resultDetail(_ result: SiteCheckResult?) -> String? {
        guard let result, result.phase == .done else { return nil }
        switch result.verdict {
        case .unresolved:
            return "Does not resolve"
        case .blocked:
            return "Blocked (\(result.resolvedIP ?? "—"))"
        case .unreachable:
            let ip = result.resolvedIP ?? "—"
            return "Resolves \(ip) · unreachable"
        case .ok:
            let ip = result.resolvedIP ?? "—"
            let status = result.httpStatus.map { "HTTP \($0)" } ?? "reachable"
            let ms = result.dnsMs.map { " · \(Int($0.rounded())) ms DNS" } ?? ""
            return "\(ip) · \(status)\(ms)"
        case .unknown:
            return nil
        }
    }

    private func verdictLabel(_ v: SiteCheckResult.Verdict) -> String {
        switch v {
        case .ok: return "OK"
        case .blocked: return "Blocked"
        case .unreachable: return "Unreachable"
        case .unresolved: return "No DNS"
        case .unknown: return "—"
        }
    }

    private func verdictColor(_ v: SiteCheckResult.Verdict) -> Color {
        switch v {
        case .ok: return Color(hex: "38EF7D")
        case .blocked: return Color(hex: "F2994A")
        case .unreachable, .unresolved: return Color(hex: "FC466B")
        case .unknown: return .secondary
        }
    }

    // MARK: - Add custom

    private var addSheet: some View {
        NavigationStack {
            Form {
                Section("Website") {
                    TextField("Name (optional)", text: Binding(
                        get: { store.newName },
                        set: { store.send(.newNameChanged($0)) }
                    ))
                    TextField("Domain (e.g. example.com)", text: Binding(
                        get: { store.newDomain },
                        set: { store.send(.newDomainChanged($0)) }
                    ))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                }
                if !store.newDomain.isEmpty {
                    Section {
                        Text("Will add: \(store.normalizedNewDomain)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add site")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.setShowAddSheet(false)) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { store.send(.addCustom) }
                        .disabled(!store.canAddCustom)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
