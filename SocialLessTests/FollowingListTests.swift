import XCTest
@testable import SocialLess

@MainActor final class FollowingListTests: XCTestCase {
    private func export(_ entries: [[String: Any]]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["relationships_following": entries])
    }
    func testImportsBothAccountFieldsDeduplicatesAndDropsOtherData() throws {
        let data = try export([["title": "Sample.One", "string_list_data": [["href": "https://example.invalid/private", "timestamp": 123]]],
                               ["title": "", "string_list_data": [["value": "sample_two"]]],
                               ["title": "sample.one", "string_list_data": [["value": "SAMPLE.ONE"]]]])
        let date = Date(timeIntervalSince1970: 1234)
        let list = try FollowingListImporter.parse(data, now: date)
        XCTAssertEqual(list.accounts, ["sample.one", "sample_two"])
        XCTAssertEqual(list.importedAt, date)
        let saved = String(decoding: try JSONEncoder().encode(list), as: UTF8.self)
        XCTAssertFalse(saved.contains("href")); XCTAssertFalse(saved.contains("example.invalid")); XCTAssertFalse(saved.contains("timestamp"))
    }
    func testRejectsWrongExportAmbiguousEntriesInvalidHandlesAndLimits() throws {
        for data in [Data("[]".utf8), Data("<html></html>".utf8), Data("PKZIP".utf8),
                     try export([]), try export([["title": "https://instagram.com/sample"]]),
                     try export([["title": "sample", "string_list_data": [["value": "different"]]]]),
                     try export([["title": "sample", "string_list_data": [["value": "sample"], ["value": "other"]]]]),
                     try export([["title": "sample..name"]]), try export([["title": "sample\n"]]),
                     try export([["title": "sample"], ["title": ""]]),
                     Data(repeating: 32, count: FollowingListImporter.maximumBytes + 1),
                     try export(Array(repeating: ["title": "sample"], count: 10_001))] {
            XCTAssertThrowsError(try FollowingListImporter.parse(data))
        }
    }
    func testBoundedFileReadAndFilePersistenceDeletion() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = FileFollowingListRepository(url: directory.appendingPathComponent("accounts.json"))
        XCTAssertNil(try repo.load())
        let list = try FollowingListImporter.parse(export([["title": "sample"]]))
        try repo.save(list)
        XCTAssertEqual(try repo.load(), list)
        XCTAssertEqual(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        let input = directory.appendingPathComponent("following.json")
        try export([["title": "another"]]).write(to: input)
        XCTAssertEqual(try FollowingListImporter.read(input).accounts, ["another"])
        try repo.delete(); XCTAssertNil(try repo.load())
        XCTAssertTrue(FileManager.default.fileExists(atPath: input.path), "Deleting imported data must preserve the user's source export")
    }
    func testRepositoryFailuresPreserveLoadedListAndDoNotEraseCorruptFile() throws {
        final class FailingRepository: FollowingListRepository {
            var value = FollowingList(accounts: ["original"], importedAt: .distantPast)
            func load() throws -> FollowingList? { value }
            func save(_ list: FollowingList) throws { throw FollowingImportError.invalidFormat }
            func delete() throws { throw FollowingImportError.invalidFormat }
        }
        let store = FollowingListStore(repository: FailingRepository())
        store.replace(with: FollowingList(accounts: ["replacement"], importedAt: Date()))
        XCTAssertEqual(store.list?.accounts, ["original"]); XCTAssertNotNil(store.error)
        store.delete(); XCTAssertEqual(store.list?.accounts, ["original"])
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("accounts.json")
        let original = Data("corrupt".utf8); try original.write(to: url)
        let corrupt = FollowingListStore(repository: FileFollowingListRepository(url: url))
        XCTAssertNil(corrupt.list); XCTAssertNotNil(corrupt.error)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
}
