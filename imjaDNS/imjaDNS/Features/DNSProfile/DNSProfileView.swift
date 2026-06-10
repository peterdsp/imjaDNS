import SwiftUI
import ComposableArchitecture

struct DNSProfileView: View {
    @Bindable var store: StoreOf<DNSProfileFeature>

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if store.isLoading {
                    loadingView
                } else {
                    categoryPicker
                    if !store.favoriteProfiles.isEmpty && store.selectedCategory == nil {
                        favoritesSection
                    }
                    profilesGrid
                    addCustomButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background { AnimatedMeshBackground() }
        .navigationTitle("DNS Profiles")
        .onAppear { store.send(.onAppear) }
        .sheet(isPresented: Binding(
            get: { store.showAddCustomSheet },
            set: { _ in store.send(.toggleAddCustomSheet) }
        )) {
            addCustomSheet
        }
        .overlay {
            if let msg = store.successMessage {
                successToast(msg)
            }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.send(.dismissError) } }
            )
        ) {
            Button("OK") { store.send(.dismissError) }
        } message: {
            if let msg = store.errorMessage {
                Text(msg)
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading DNS Profiles...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                categoryChip(nil, label: "All", icon: "globe")
                ForEach(DNSCategory.allCases) { category in
                    categoryChip(category, label: category.rawValue, icon: category.icon)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func categoryChip(_ category: DNSCategory?, label: String, icon: String) -> some View {
        let isSelected = store.selectedCategory == category
        return Button {
            store.send(.selectCategory(category))
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    Capsule().fill(AppTheme.accentGradient)
                } else {
                    Capsule().fill(.ultraThinMaterial)
                }
            }
            .foregroundStyle(isSelected ? .white : .primary)
        }
    }

    // MARK: - Favorites

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Favorites", icon: "star.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.favoriteProfiles) { profile in
                        compactProfileCard(profile)
                    }
                }
            }
        }
    }

    private func compactProfileCard(_ profile: DNSProfile) -> some View {
        Button {
            store.send(.applyProfile(profile))
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(AppTheme.categoryGradient(for: profile.category))
                        .frame(width: 44, height: 44)
                    Image(systemName: profile.category.icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Text(profile.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                if store.activeProfileID == profile.id {
                    Text("Active")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(hex: "38EF7D")))
                }
            }
            .frame(width: 80)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Profiles Grid

    private var profilesGrid: some View {
        LazyVStack(spacing: 12) {
            ForEach(store.filteredProfiles) { profile in
                profileCard(profile)
            }
        }
    }

    private func profileCard(_ profile: DNSProfile) -> some View {
        let isActive = store.activeProfileID == profile.id

        return GlassCard {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.categoryGradient(for: profile.category))
                            .frame(width: 50, height: 50)
                        Image(systemName: profile.category.icon)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(profile.name)
                                .font(.headline)
                            if isActive {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color(hex: "38EF7D"))
                            }
                        }

                        Text(profile.serversDisplay)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            Text(profile.protocolType.displayName)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.ultraThinMaterial))

                            Text(profile.category.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(spacing: 8) {
                        Button {
                            store.send(.toggleFavorite(profile))
                        } label: {
                            Image(systemName: profile.isFavorite ? "star.fill" : "star")
                                .font(.body)
                                .foregroundStyle(profile.isFavorite ? Color(hex: "F2C94C") : .secondary)
                        }

                        if let latency = store.latencyResults[profile.id] {
                            LatencyBadge(latencyMs: latency)
                        }
                    }
                }

                if !profile.description.isEmpty {
                    Text(profile.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 10) {
                    Button {
                        store.send(.applyProfile(profile))
                    } label: {
                        HStack(spacing: 6) {
                            if store.isApplying && store.activeProfileID == profile.id {
                                ProgressView()
                                    .controlSize(.mini)
                                    .tint(.white)
                            } else {
                                Image(systemName: isActive ? "checkmark.shield.fill" : "shield.checkered")
                                    .font(.caption.weight(.semibold))
                            }
                            Text(isActive ? "Active" : "Apply")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background {
                            if isActive {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(hex: "38EF7D"))
                            } else {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(AppTheme.accentGradient)
                            }
                        }
                        .foregroundStyle(.white)
                    }
                    .disabled(store.isApplying)

                    if !profile.isBuiltIn {
                        Button {
                            store.send(.deleteCustomProfile(profile))
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(hex: "FC466B"))
                                .padding(11)
                                .background {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                }
                        }
                    }
                }
            }
        }
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .stroke(Color(hex: "38EF7D").opacity(0.5), lineWidth: 1.5)
            }
        }
    }

    // MARK: - Add Custom

    private var addCustomButton: some View {
        Button {
            store.send(.toggleAddCustomSheet)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("Add Custom DNS")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(hex: "00D2FF").opacity(0.5), Color(hex: "7B61FF").opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5,
                        antialiased: true
                    )
                    .background {
                        RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
            }
            .foregroundStyle(AppTheme.accentGradient)
        }
    }

    // MARK: - Add Custom Sheet

    private var addCustomSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Profile Name")
                            .font(.subheadline.weight(.medium))
                        TextField("e.g. My Custom DNS", text: $store.customName.sending(\.updateCustomName))
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("DNS Servers")
                            .font(.subheadline.weight(.medium))
                        Text("Enter one or more DNS server IPs, separated by commas")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. 1.1.1.1, 1.0.0.1", text: $store.customServers.sending(\.updateCustomServers))
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.numbersAndPunctuation)
                    }

                    Button {
                        store.send(.addCustomProfile)
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Profile")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.accentGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Add Custom DNS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.send(.toggleAddCustomSheet)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Success Toast

    private func successToast(_ message: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: "38EF7D"))
                Text(message)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Capsule().fill(.ultraThickMaterial))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .padding(.bottom, 20)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4), value: store.successMessage)
    }
}
