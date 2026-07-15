import SwiftUI
import ComposableArchitecture
import UniformTypeIdentifiers
import VisionKit

struct ShareSyncView: View {
    @Bindable var store: StoreOf<ShareSyncFeature>

    @State private var showExporter = false
    @State private var showImporter = false
    @State private var showScanner = false
    @State private var qrProfile: DNSProfile?

    var body: some View {
        List {
            Section {
                Toggle("Sync with iCloud", isOn: Binding(
                    get: { store.syncEnabled },
                    set: { store.send(.setSync($0)) }
                ))
            } header: {
                Text("iCloud")
            } footer: {
                Text("Syncs your custom profiles, favorites, and automation rules across your devices. No browsing or DNS query data is ever synced.")
            }

            Section("Backup") {
                Button {
                    showExporter = true
                } label: {
                    Label("Export all profiles", systemImage: "square.and.arrow.up")
                }
                .disabled(store.customProfiles.isEmpty)

                Button {
                    showImporter = true
                } label: {
                    Label("Import profiles", systemImage: "square.and.arrow.down")
                }
            }

            Section {
                Button {
                    showScanner = true
                } label: {
                    Label("Scan a profile QR", systemImage: "qrcode.viewfinder")
                }
                .disabled(!scannerAvailable)
            } header: {
                Text("Share")
            } footer: {
                if !scannerAvailable {
                    Text("QR scanning needs a camera and iOS 16 or later.")
                }
            }

            if !store.customProfiles.isEmpty {
                Section("Show a profile's QR") {
                    ForEach(store.customProfiles) { profile in
                        Button {
                            qrProfile = profile
                        } label: {
                            Label(profile.name, systemImage: "qrcode")
                        }
                    }
                }
            }
        }
        .navigationTitle("Share & Sync")
        .onAppear { store.send(.onAppear) }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "imjaDNS-profiles"
        ) { _ in }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json]
        ) { result in
            handleImport(result)
        }
        .sheet(item: $qrProfile) { profile in
            qrSheet(for: profile)
        }
        .sheet(isPresented: $showScanner) {
            scannerSheet
        }
        .alert("Import", isPresented: Binding(
            get: { store.message != nil },
            set: { if !$0 { store.send(.dismissMessage) } }
        )) {
            Button("OK") { store.send(.dismissMessage) }
        } message: {
            Text(store.message ?? "")
        }
    }

    // MARK: - Export

    private var exportDocument: ProfilesDocument {
        let data = (try? ProfileTransfer.encode(store.customProfiles)) ?? Data()
        return ProfilesDocument(data: data)
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case let .success(url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        store.send(.importData(data))
    }

    // MARK: - QR

    private func qrSheet(for profile: DNSProfile) -> some View {
        VStack(spacing: 20) {
            Text(profile.name).font(.headline)
            if let data = try? ProfileTransfer.encode([profile]),
               let image = QRGenerator.image(from: data) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260, maxHeight: 260)
                    .padding()
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Text("Couldn't generate a QR code.").foregroundStyle(.secondary)
            }
            Text("Scan this from another device's Share & Sync screen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Done") { qrProfile = nil }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "00D2FF"))
        }
        .padding(28)
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var scannerSheet: some View {
        if #available(iOS 16.0, *) {
            QRScannerView(
                onScan: { payload in
                    showScanner = false
                    store.send(.importText(payload))
                },
                onError: { _ in showScanner = false }
            )
            .ignoresSafeArea()
        } else {
            Text("QR scanning requires iOS 16 or later.")
        }
    }

    private var scannerAvailable: Bool {
        if #available(iOS 16.0, *) {
            return DataScannerViewController.isSupported && DataScannerViewController.isAvailable
        }
        return false
    }
}
