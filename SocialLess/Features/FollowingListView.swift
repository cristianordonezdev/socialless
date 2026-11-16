import SwiftUI
import UniformTypeIdentifiers

struct FollowingListView: View {
    @Bindable var store: FollowingListStore
    @State private var choosing = false
    @State private var reading = false
    @State private var preview: FollowingList?
    @State private var importError: String?
    @State private var deleting = false
    var body: some View {
        Form {
            Section("Import accounts you follow") {
                Text("In Instagram’s Accounts Center, export your followers and following information in JSON format. Unzip the download in Files, then select following.json here.")
                Text("The export is a snapshot, not a live connection. Choose an all-time export from the same Instagram account you use in SocialLess. Import again when your following list changes.")
                Button(reading ? "Reading file…" : "Choose following.json") { choosing = true }
                    .disabled(reading).accessibilityIdentifier("following.import")
                Text("Only account names and the import date are saved on this device, excluded from device backups. The export itself, URLs and other account data are not copied. Nothing is uploaded by SocialLess.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--uitesting"),
               ProcessInfo.processInfo.arguments.contains("--following-import-fixture") {
                Button("Preview fictional import") {
                    preview = try? FollowingListImporter.parse(Data(#"{"relationships_following":[{"title":"sample_friend"}]}"#.utf8))
                }.accessibilityIdentifier("following.fixture")
            }
            #endif
            if let preview {
                Section("Review import") {
                    Text("\(preview.accounts.count) unique accounts")
                    ForEach(Array(preview.accounts.prefix(8)), id: \.self) { Text("@\($0)") }
                    if preview.accounts.count > 8 { Text("And \(preview.accounts.count - 8) more") }
                    Button(store.list == nil ? "Save this list" : "Replace saved list") {
                        store.replace(with: preview)
                        if store.error == nil { self.preview = nil }
                    }.accessibilityIdentifier("following.save")
                    Button("Cancel import", role: .cancel) { self.preview = nil }
                    Text("Saving replaces the previous list. It does not turn on feed filtering.").font(.footnote)
                }
            }
            if let list = store.list {
                Section("Saved on this device") {
                    LabeledContent("Accounts", value: String(list.accounts.count))
                    LabeledContent("Imported", value: list.importedAt.formatted(date: .abbreviated, time: .shortened))
                    Button("Delete following list", role: .destructive) { deleting = true }
                        .accessibilityIdentifier("following.delete")
                }
            }
            if let error = importError ?? store.error {
                Section { Text(error).foregroundStyle(.secondary).accessibilityIdentifier("following.error") }
            }
            Section("Experimental feed filter") {
                Text("During an Instagram website session, open Filters and turn on Only imported accounts. It starts off each session. Unrecognized posts stay visible; a sparse or empty feed is possible. This does not fetch posts or verify who you currently follow.")
            }
        }.navigationTitle("Following list")
            .fileImporter(isPresented: $choosing, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    reading = true; importError = nil; preview = nil
                    Task {
                        do { preview = try await Task.detached { try FollowingListImporter.read(url) }.value }
                        catch let error as FollowingImportError { importError = error.message }
                        catch { importError = "The file could not be read. Try downloading it in Files first. Your saved list has not changed." }
                        reading = false
                    }
                case .failure:
                    importError = "The file could not be opened. Your saved list has not changed."
                }
            }
            .confirmationDialog("Delete the saved following list?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete list", role: .destructive) { store.delete(); preview = nil }
            } message: { Text("This turns off the imported-account filter. Website sign-in and session history are kept.") }
    }
}
