//
//  FileTrayViewModel.swift
//  DynamicNotch
//
//  Created by Евгений Петрукович on 4/26/26.
//

import Foundation
import Combine
internal import AppKit

enum FileTrayPasteboard {
    static let localDragTypeIdentifier = "com.dynamicnotch.file-tray.local-drag"
    static let localDragPasteboardType = NSPasteboard.PasteboardType(localDragTypeIdentifier)
}

final class FileTrayPasteboardWriter: NSObject, NSPasteboardWriting {
    private let url: URL

    init(url: URL) {
        self.url = url.standardizedFileURL
    }

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [.fileURL, .URL, FileTrayPasteboard.localDragPasteboardType]
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type {
        case .fileURL, .URL:
            return url.absoluteString
        case FileTrayPasteboard.localDragPasteboardType:
            return Data([1])
        default:
            return nil
        }
    }
}

private enum FileTrayRemovalPolicy: String, Codable {
    case deleteCopy
    case trashMovedOriginal
}

struct FileTrayItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let displayName: String
    let isDirectory: Bool
    fileprivate let removalPolicy: FileTrayRemovalPolicy

    fileprivate init(
        url: URL,
        id: UUID = UUID(),
        removalPolicy: FileTrayRemovalPolicy = .deleteCopy
    ) {
        let standardizedURL = url.standardizedFileURL
        var isDirectoryValue: ObjCBool = false

        FileManager.default.fileExists(
            atPath: standardizedURL.path,
            isDirectory: &isDirectoryValue
        )

        self.id = id
        self.url = standardizedURL
        self.displayName = standardizedURL.lastPathComponent.isEmpty ?
        standardizedURL.deletingLastPathComponent().lastPathComponent :
        standardizedURL.lastPathComponent
        self.isDirectory = isDirectoryValue.boolValue
        self.removalPolicy = removalPolicy
    }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    var itemProvider: NSItemProvider {
        let provider = NSItemProvider(object: url as NSURL)
        provider.suggestedName = displayName
        provider.registerDataRepresentation(
            forTypeIdentifier: FileTrayPasteboard.localDragTypeIdentifier,
            visibility: .ownProcess
        ) { completion in
            completion(Data([1]), nil)
            return nil
        }
        return provider
    }

    var movesOutOfTrayOnDrag: Bool {
        removalPolicy == .trashMovedOriginal
    }
}

private struct FileTrayStoredItem: Codable {
    let id: UUID
    let path: String
    let removalPolicy: FileTrayRemovalPolicy

    init(id: UUID, path: String, removalPolicy: FileTrayRemovalPolicy) {
        self.id = id
        self.path = path
        self.removalPolicy = removalPolicy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        path = try container.decode(String.self, forKey: .path)
        removalPolicy = try container.decodeIfPresent(
            FileTrayRemovalPolicy.self,
            forKey: .removalPolicy
        ) ?? .trashMovedOriginal
    }
}

@MainActor
final class FileTrayViewModel: ObservableObject {
    @Published var selectedItemIDs: Set<FileTrayItem.ID> = []
    @Published private(set) var items: [FileTrayItem] = []

    private static let persistedItemsKey = "settings.live.tray.persistedItems"
    private let defaults: UserDefaults
    private let storage: FileTrayStorage

    init(defaults: UserDefaults = .standard, storageRootURL: URL? = nil) {
        self.defaults = defaults
        self.storage = FileTrayStorage(rootURL: storageRootURL ?? FileTrayStorage.defaultRootURL)
        restorePersistedItems()
        // NotchFlow: never delete untracked files during startup.
    }

    var onItemsChange: (([FileTrayItem]) -> Void)? {
        didSet {
            onItemsChange?(items)
        }
    }

    var count: Int {
        items.count
    }

    var selectedCount: Int {
        selectedItems.count
    }

    var hasSelection: Bool {
        selectedItemIDs.isEmpty == false
    }

    var selectedItems: [FileTrayItem] {
        items.filter { selectedItemIDs.contains($0.id) }
    }

    func add(_ urls: [URL]) {
        add(urls, removalPolicy: .deleteCopy)
    }

    private func add(_ urls: [URL], removalPolicy: FileTrayRemovalPolicy) {
        var knownIdentities = Set(items.map { Self.identity(for: $0.url) })
        let newItems = urls.compactMap { url -> FileTrayItem? in
            let standardizedURL = url.standardizedFileURL
            guard standardizedURL.isFileURL else { return nil }

            let identity = Self.identity(for: standardizedURL)
            guard knownIdentities.insert(identity).inserted else { return nil }

            return FileTrayItem(url: standardizedURL, removalPolicy: removalPolicy)
        }

        guard !newItems.isEmpty else { return }

        updateItems(items + newItems)
    }

    func add(_ urls: [URL], mode: FileTrayUsageMode) throws {
        switch mode {
        case .copy:
            let importedURLs = try storage.importItems(from: urls, moveOriginals: false)
            add(importedURLs, removalPolicy: .deleteCopy)

        case .moveOriginals:
            let importedURLs = try storage.importItems(from: urls, moveOriginals: true)
            add(importedURLs, removalPolicy: .trashMovedOriginal)
        }
    }

    func toggleSelection(for item: FileTrayItem) {
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
    }

    func selectAll() {
        selectedItemIDs = Set(items.map { $0.id })
    }

    func clearSelection() {
        selectedItemIDs.removeAll()
    }

    func itemsForDrag(startingAt item: FileTrayItem) -> [FileTrayItem] {
        if selectedItemIDs.contains(item.id) {
            return selectedItems
        }

        return [item]
    }

    func remove(_ item: FileTrayItem) {
        updateItems(items.filter { $0.id != item.id })
        removeStoredFiles(for: [item])
    }

    func removeSelectedItems() {
        guard hasSelection else { return }

        let removedItems = items.filter { selectedItemIDs.contains($0.id) }
        let remainingItems = items.filter { selectedItemIDs.contains($0.id) == false }

        updateItems(remainingItems)
        removeStoredFiles(for: removedItems)
    }

    func clear() {
        let removedItems = items

        updateItems([])
        removeStoredFiles(for: removedItems)
    }

    func forgetMovedOutItems(_ movedItems: [FileTrayItem]) {
        let movedItemIDs = Set(
            movedItems
                .filter(\.movesOutOfTrayOnDrag)
                .map(\.id)
        )

        guard movedItemIDs.isEmpty == false else {
            return
        }

        updateItems(items.filter { movedItemIDs.contains($0.id) == false })
    }


    private func updateItems(_ newItems: [FileTrayItem]) {
        items = newItems
        selectedItemIDs.formIntersection(Set(newItems.map(\.id)))
        persistItems()
        onItemsChange?(newItems)
    }

    private static func identity(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private func removeStoredFiles(for removedItems: [FileTrayItem]) {
        for item in removedItems {
            switch item.removalPolicy {
            case .deleteCopy:
                storage.deleteIfStoredInTray(item.url)

            case .trashMovedOriginal:
                storage.trashIfStoredInTray(item.url)
            }
        }
    }


    private func persistItems() {
        let storedItems = items.map {
            FileTrayStoredItem(
                id: $0.id,
                path: $0.url.path,
                removalPolicy: $0.removalPolicy
            )
        }

        do {
            let data = try JSONEncoder().encode(storedItems)
            defaults.set(data, forKey: Self.persistedItemsKey)
        } catch {
            defaults.removeObject(forKey: Self.persistedItemsKey)
        }
    }

    private func restorePersistedItems() {
        guard let data = defaults.data(forKey: Self.persistedItemsKey) else {
            return
        }

        do {
            let storedItems = try JSONDecoder().decode([FileTrayStoredItem].self, from: data)

            let restoredItems = storedItems.compactMap { storedItem -> FileTrayItem? in
                let url = URL(fileURLWithPath: storedItem.path).standardizedFileURL

                guard FileManager.default.fileExists(atPath: url.path) else {
                    return nil
                }

                return FileTrayItem(
                    url: url,
                    id: storedItem.id,
                    removalPolicy: storedItem.removalPolicy
                )
            }

            items = restoredItems
            selectedItemIDs = []

            if restoredItems.count != storedItems.count {
                persistItems()
            }
        } catch {
            defaults.removeObject(forKey: Self.persistedItemsKey)
        }
    }
}

private struct FileTrayStorage {
    let rootURL: URL
    static var defaultRootURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NotchFlow", isDirectory: true)
            .appendingPathComponent("FileTray", isDirectory: true)
    }

    func removeUntrackedItems(keeping keptURLs: [URL]) {
        let root = rootURL.standardizedFileURL.resolvingSymlinksInPath()
        let keptPaths = Set(
            keptURLs.map {
                $0.standardizedFileURL.resolvingSymlinksInPath().path
            }
        )

        guard let storedURLs = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for storedURL in storedURLs {
            let storedPath = storedURL.standardizedFileURL.resolvingSymlinksInPath().path

            guard keptPaths.contains(storedPath) == false else {
                continue
            }

            deleteIfStoredInTray(storedURL)
        }
    }

    func deleteIfStoredInTray(_ url: URL) {
        guard let fileURL = storedFileURL(for: url) else {
            return
        }

        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            NSLog("Failed to delete File Tray copy: %@", error.localizedDescription)
        }
    }

    func trashIfStoredInTray(_ url: URL) {
        guard let fileURL = storedFileURL(for: url) else {
            return
        }

        var trashedURL: NSURL?
        do {
            try FileManager.default.trashItem(at: fileURL, resultingItemURL: &trashedURL)
        } catch {
            NSLog("Failed to move File Tray item to Trash: %@", error.localizedDescription)
        }
    }

    private func storedFileURL(for url: URL) -> URL? {
        let fileURL = url.standardizedFileURL.resolvingSymlinksInPath()
        let storageRootURL = rootURL.standardizedFileURL.resolvingSymlinksInPath()
        let storageRootPath = storageRootURL.path + "/"

        guard fileURL.path.hasPrefix(storageRootPath),
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        return fileURL
    }

    func importItems(from urls: [URL], moveOriginals: Bool) throws -> [URL] {
        // Validate the whole batch before moving any original.
        for url in urls {
            guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else {
                throw CocoaError(.fileNoSuchFile)
            }
        }
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )

        var completed: [(source: URL, destination: URL)] = []
        do {
            for sourceURL in urls {
                let source = sourceURL.standardizedFileURL
                let destination = uniqueDestinationURL(for: source, in: rootURL)
                if moveOriginals {
                    try FileManager.default.moveItem(at: source, to: destination)
                } else {
                    try FileManager.default.copyItem(at: source, to: destination)
                }
                completed.append((source, destination))
            }
            return completed.map(\.destination)
        } catch {
            var rollbackFailed = false
            for item in completed.reversed() {
                do {
                    if moveOriginals { try FileManager.default.moveItem(at: item.destination, to: item.source) }
                    else { try FileManager.default.removeItem(at: item.destination) }
                } catch { rollbackFailed = true }
            }
            if rollbackFailed {
                throw NSError(domain: "NotchFlow.FileTray", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "The import could not be completed. Some files remain in \(rootURL.path).",
                    NSUnderlyingErrorKey: error
                ])
            }
            throw error
        }
    }

    private func uniqueDestinationURL(for sourceURL: URL, in folder: URL) -> URL {
        let preferredName = sourceURL.lastPathComponent
        let baseURL = folder.appendingPathComponent(preferredName, isDirectory: sourceURL.hasDirectoryPath)

        guard FileManager.default.fileExists(atPath: baseURL.path) else {
            return baseURL
        }

        let name = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension

        for index in 1...999 {
            let fileName = ext.isEmpty ? "\(name) \(index)" : "\(name) \(index).\(ext)"
            let candidate = folder.appendingPathComponent(fileName, isDirectory: sourceURL.hasDirectoryPath)

            if FileManager.default.fileExists(atPath: candidate.path) == false {
                return candidate
            }
        }

        return folder.appendingPathComponent(UUID().uuidString, isDirectory: sourceURL.hasDirectoryPath)
    }
}
