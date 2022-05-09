//
//  LogbookTests.swift
//
//
//  Created by Christopher Richez on 5/9/22
//

@testable
import Logbook
import XCTest
import Foundation
import SystemPackage

/// A test suite for each method in the `Logbook` class.
final class LogbookTests: XCTestCase {
    /// The URL to the test file.
    var testFileURL: URL {
        /// The test file location for this platform.
        try! FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("test")
        .appendingPathExtension("logbook")
    }
    
    /// The path to the test file.
    var testFilePath: FilePath {
        FilePath(testFileURL.path)
    }
    
    /// Erases any pre-existing logbook file.
    override func setUpWithError() throws {
        do {
            // Ensure there is no test file before starting the test.
            try FileManager.default.removeItem(at: testFileURL)
        } catch CocoaError.fileNoSuchFile {
            // If the file doesn't exist, continue the test.
        }
    }
    
    /// Asserts `Logbook/createEmptyFile(at:)` creates an empty database file at the provided path.
    func testEmptyFileCreated() throws {
        try Logbook.createEmptyFile(at: testFilePath)
        let contents = try Data(contentsOf: testFileURL)
        XCTAssertEqual(contents.count, 16 + 256 * 8)
        XCTAssertEqual(Array(contents[0..<8]), [0, 1, 0, 0, 0, 0, 0, 0])
    }
    
    /// Asserts `Logbook/init(location:)` creates an empty logbook file if there isn't already one.
    func testFirstLogbookInit() throws {
        let _ = try Logbook(location: testFilePath)
        let contents = try Data(contentsOf: testFileURL)
        XCTAssertEqual(contents.count, 16 + 256 * 8)
        XCTAssertEqual(Array(contents[0..<8]), [0, 1, 0, 0, 0, 0, 0, 0])
    }
    
    /// Asserts `Logbook/init(location:)` loads existing data as expected.
    func testLaterLogbookInit() throws {
        let testFile = try FileDescriptor.open(
            testFilePath, .readWrite,
            options: .create,
            permissions: .ownerReadWriteExecute)
        try testFile.closeAfter {
            try withUnsafeBytes(of: (128, 64)) {
                guard try testFile.write($0) == 16 else {
                    XCTFail("didn't write all test file bytes")
                    return
                }
            }
        }
        let testBook = try Logbook(location: testFilePath)
        XCTAssertEqual(testBook.capacity, 128)
        XCTAssertEqual(testBook.count, 64)
    }
}
