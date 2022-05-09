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
    /// Asserts `createEmptyFile(at:)` creates an empty database file at the provided path.
    func testEmptyFileCreated() throws {
        /// The test file location for this platform.
        let location = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("test")
        .appendingPathExtension("logbook")
        do {
            // Ensure there is no test file before starting the test.
            try FileManager.default.removeItem(at: location)
        } catch CocoaError.fileNoSuchFile {
            // If the file doesn't exist, continue the test.
        }
        /// The test logbook.
        try Logbook.createEmptyFile(at: FilePath(location.path))
        let contents = try Data(contentsOf: location)
        XCTAssertEqual(contents.count, 16 + 256 * 8)
        XCTAssertEqual(Array(contents[0..<8]), [0, 1, 0, 0, 0, 0, 0, 0])
    }
}
