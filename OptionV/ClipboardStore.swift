import Foundation
import UniformTypeIdentifiers

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
    @Published private(set) var persistenceErrorMessage: String?

    private let fileManager = FileManager.default
    private let historyURL: URL
    private let cipher: LocalDataCipher
    private var canPersist = true
    private var hasLoaded = false
    private(set) var limit: Int
    private(set) var retention: ClipboardRetention

    init(
        directoryURL: URL? = nil,
        limit: Int = 200,
        retention: ClipboardRetention = .never,
        cipher: LocalDataCipher = .keychainBacked,
        loadImmediately: Bool = true
    ) {
        let directory = directoryURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OptionV", isDirectory: true)
        historyURL = directory.appendingPathComponent("history.json")
        self.cipher = cipher
        self.limit = max(limit, 10)
        self.retention = retention
        canPersist = loadImmediately
        if loadImmediately { load() }
    }

    func setLimit(_ value: Int) {
        limit = max(value, 10)
        if trimToLimit() { save() }
    }

    func setRetention(_ value: ClipboardRetention, now: Date = Date()) {
        retention = value
        if pruneExpired(now: now, persist: false) > 0 {
            save()
        }
    }

    @discardableResult
    func setPinned(_ id: UUID, pinned: Bool) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }
        items[index].isPinned = pinned
        sortItems()
        _ = trimToLimit()
        save()
        return true
    }

    @discardableResult
    func remove(_ id: UUID) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }
        items.remove(at: index)
        save()
        return true
    }

    func item(withID id: UUID) -> ClipboardItem? {
        items.first(where: { $0.id == id })
    }

    @discardableResult
    func clearUnpinned() -> Int {
        let originalCount = items.count
        items.removeAll { !$0.isPinned }
        let removedCount = originalCount - items.count
        if removedCount > 0 { save() }
        return removedCount
    }

    func ingest(
        _ snapshot: ClipboardSnapshot,
        sourceApplication: ClipboardSourceApplication? = nil,
        now: Date = Date()
    ) {
        guard !snapshot.isEmpty else { return }
        let fileReferences = snapshot.fileURLs.compactMap(makeFileReference)
        let existingItem = items.first(where: { $0.fingerprint == snapshot.fingerprint })
        let wasPinned = existingItem?.isPinned ?? false
        let item = ClipboardItem(
            id: existingItem?.id ?? UUID(),
            createdAt: now,
            fingerprint: snapshot.fingerprint,
            text: snapshot.text,
            richTextData: snapshot.richTextData,
            imageData: snapshot.imageData,
            imageType: snapshot.imageType,
            ocrText: existingItem?.ocrText,
            files: fileReferences,
            isPinned: wasPinned,
            sourceApplication: sourceApplication ?? existingItem?.sourceApplication
        )
        guard !item.isEmpty else { return }

        items.removeAll { $0.fingerprint == item.fingerprint }
        items.insert(item, at: 0)
        _ = pruneExpired(now: now, persist: false)
        sortItems()
        _ = trimToLimit()
        save()
        scheduleOCRIfNeeded(for: item)
    }

    @discardableResult
    func pruneExpired(now: Date = Date()) -> Int {
        pruneExpired(now: now, persist: true)
    }

    func clear() {
        items.removeAll()
        save()
    }

    private func setOCRText(_ text: String, for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        guard items[index].ocrText != text else { return }
        items[index].ocrText = text
        save()
    }

    private func makeFileReference(url: URL) -> StoredFileReference? {
        let bookmark: Data
        do {
            bookmark = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            guard let fallback = try? url.bookmarkData() else { return nil }
            bookmark = fallback
        }
        return StoredFileReference(url: url, bookmarkData: bookmark)
    }

    func suspendPersistence(message: String) {
        canPersist = false
        persistenceErrorMessage = message
    }

    func load() {
        canPersist = true
        persistenceErrorMessage = nil
        if hasLoaded {
            save()
            return
        }
        guard fileManager.fileExists(atPath: historyURL.path) else {
            hasLoaded = true
            if !items.isEmpty { save() }
            return
        }
        do {
            let storedData = try Data(contentsOf: historyURL)
            let openedData = try cipher.open(storedData, purpose: "clipboard-history")
            let storedItems = try JSONDecoder.clipboardDecoder.decode([ClipboardItem].self, from: openedData.plaintext)
            let pendingFingerprints = Set(items.map(\.fingerprint))
            let hadPendingItems = !items.isEmpty
            for index in items.indices {
                if let stored = storedItems.first(where: { $0.fingerprint == items[index].fingerprint }),
                   stored.id != items[index].id {
                    items[index].isPinned = items[index].isPinned || stored.isPinned
                }
            }
            items += storedItems.filter { !pendingFingerprints.contains($0.fingerprint) }
            hasLoaded = true
            let removedCount = pruneExpired(now: Date(), persist: false)
            sortItems()
            let trimmed = trimToLimit()
            if hadPendingItems || removedCount > 0 || trimmed || !openedData.wasEncrypted { save() }
            items.forEach { scheduleOCRIfNeeded(for: $0) }
        } catch {
            canPersist = false
            persistenceErrorMessage = String(localized: "Encrypted history could not be opened. Existing data was preserved.")
        }
    }

    private func scheduleOCRIfNeeded(for item: ClipboardItem) {
        guard item.ocrText == nil,
              let imageData = item.imageData,
              item.imageType != UTType.gif.identifier else { return }

        let itemID = item.id
        Task { [weak self] in
            let recognizedText = await Task.detached(priority: .utility) {
                LocalOCRService.recognize(imageData: imageData)
            }.value

            guard let recognizedText, !recognizedText.isEmpty else { return }
            self?.setOCRText(recognizedText, for: itemID)
        }
    }

    private func pruneExpired(now: Date, persist: Bool) -> Int {
        guard let interval = retention.interval else { return 0 }
        let cutoff = now.addingTimeInterval(-interval)
        let originalCount = items.count
        items.removeAll { !$0.isPinned && $0.createdAt < cutoff }
        let removedCount = originalCount - items.count
        if removedCount > 0 && persist { save() }
        return removedCount
    }

    @discardableResult
    private func trimToLimit() -> Bool {
        let originalCount = items.count
        var unpinnedCount = 0
        items.removeAll { item in
            guard !item.isPinned else { return false }
            unpinnedCount += 1
            return unpinnedCount > limit
        }
        return items.count != originalCount
    }

    private func sortItems() {
        items.sort {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.createdAt > $1.createdAt
        }
    }

    private func save() {
        guard canPersist else { return }
        do {
            let directory = historyURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let plaintext = try JSONEncoder.clipboardEncoder.encode(items)
            let encryptedData = try cipher.seal(plaintext, purpose: "clipboard-history")
            try encryptedData.write(to: historyURL, options: .atomic)
            try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: historyURL.path)
        } catch {
            canPersist = false
            persistenceErrorMessage = String(localized: "Encrypted history could not be saved. Clipboard capture remains available in memory.")
        }
    }
}

@MainActor
final class SnippetStore: ObservableObject {
    @Published private(set) var snippets: [ClipboardSnippet] = []
    @Published private(set) var persistenceErrorMessage: String?

    private let fileManager = FileManager.default
    private let snippetsURL: URL
    private let cipher: LocalDataCipher
    private var canPersist = true
    private var hasLoaded = false

    init(directoryURL: URL? = nil, cipher: LocalDataCipher = .keychainBacked, loadImmediately: Bool = true) {
        let directory = directoryURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OptionV", isDirectory: true)
        snippetsURL = directory.appendingPathComponent("snippets.json")
        self.cipher = cipher
        canPersist = loadImmediately
        if loadImmediately { load() }
    }

    @discardableResult
    func add(
        title: String? = nil,
        text: String,
        collection: String? = nil,
        tags: [String] = [],
        now: Date = Date()
    ) -> ClipboardSnippet? {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return nil }
        if let existing = snippets.first(where: { $0.text == normalizedText }) {
            return existing
        }

        let normalizedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let snippet = ClipboardSnippet(
            createdAt: now,
            title: normalizedTitle?.isEmpty == false
                ? normalizedTitle!
                : ClipboardSnippet.suggestedTitle(for: normalizedText),
            text: normalizedText,
            collection: collection,
            tags: tags
        )
        snippets.insert(snippet, at: 0)
        save()
        return snippet
    }

    @discardableResult
    func update(_ snippet: ClipboardSnippet) -> Bool {
        let normalizedText = snippet.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty,
              let index = snippets.firstIndex(where: { $0.id == snippet.id })
        else { return false }

        var updated = snippet
        updated.title = snippet.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if updated.title.isEmpty {
            updated.title = ClipboardSnippet.suggestedTitle(for: normalizedText)
        }
        updated.text = normalizedText
        updated.collection = ClipboardSnippet.normalizedCollection(snippet.collection)
        updated.tags = ClipboardSnippet.normalizedTags(snippet.tags)
        snippets[index] = updated
        sortSnippets()
        save()
        return true
    }

    @discardableResult
    func upsert(_ snippet: ClipboardSnippet) -> Bool {
        if snippets.contains(where: { $0.id == snippet.id }) {
            return update(snippet)
        }
        return add(
            title: snippet.title,
            text: snippet.text,
            collection: snippet.collection,
            tags: snippet.tags,
            now: snippet.createdAt
        ) != nil
    }

    @discardableResult
    func remove(_ id: UUID) -> Bool {
        guard let index = snippets.firstIndex(where: { $0.id == id }) else { return false }
        snippets.remove(at: index)
        save()
        return true
    }

    func suspendPersistence(message: String) {
        canPersist = false
        persistenceErrorMessage = message
    }

    func load() {
        canPersist = true
        persistenceErrorMessage = nil
        if hasLoaded {
            save()
            return
        }
        guard fileManager.fileExists(atPath: snippetsURL.path) else {
            hasLoaded = true
            if !snippets.isEmpty { save() }
            return
        }
        do {
            let storedData = try Data(contentsOf: snippetsURL)
            let openedData = try cipher.open(storedData, purpose: "clipboard-library")
            let storedSnippets = try JSONDecoder.clipboardDecoder.decode([ClipboardSnippet].self, from: openedData.plaintext)
            let pendingTexts = Set(snippets.map(\.text))
            let hadPendingItems = !snippets.isEmpty
            snippets += storedSnippets.filter { !pendingTexts.contains($0.text) }
            hasLoaded = true
            snippets = snippets.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            sortSnippets()
            if hadPendingItems || !openedData.wasEncrypted { save() }
        } catch {
            canPersist = false
            persistenceErrorMessage = String(localized: "Encrypted Library data could not be opened. Existing data was preserved.")
        }
    }

    private func sortSnippets() {
        snippets.sort { $0.createdAt > $1.createdAt }
    }

    private func save() {
        guard canPersist else { return }
        do {
            let directory = snippetsURL.deletingLastPathComponent()
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let plaintext = try JSONEncoder.clipboardEncoder.encode(snippets)
            let encryptedData = try cipher.seal(plaintext, purpose: "clipboard-library")
            try encryptedData.write(to: snippetsURL, options: .atomic)
            try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: snippetsURL.path)
        } catch {
            canPersist = false
            persistenceErrorMessage = String(localized: "Encrypted Library data could not be saved. Items remain available in memory.")
        }
    }
}

private extension JSONEncoder {
    static var clipboardEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var clipboardDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
