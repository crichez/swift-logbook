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
@available(macOS 11, tvOS 14, iOS 14, watchOS 8, *)
final class LogbookTests: XCTestCase {
    
    // MARK: File Management
    
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
    
    /// Removes all test data to avoid test contamination
    override func setUpWithError() throws {
        do {
            // Remove any existing test files
            try FileManager.default.removeItem(at: testFileURL)
        } catch CocoaError.fileNoSuchFile {
            // Do nothing
        }
    }
    
    /// Asserts passing a list of unsorted events to the logbook sorts and stores them as expected.
    ///
    /// This is an internal method that is used for retrieval tests later in this file.
    /// This test is a pre-condition to the rest of the suite.
    func testInitWithEvents() async throws {
        // Generate 10 unique events at random dates.
        var randomEvents = Set<Event>()
        for _ in 1 ... 10 {
            let random = Double.random(in: .leastNonzeroMagnitude ... .greatestFiniteMagnitude)
            let event = Event(date: Date(timeIntervalSinceNow: random))
            randomEvents.insert(event)
        }
        // Pass them to a new logbook.
        let logbook = Logbook(location: FilePath("/dev/null"), events: randomEvents)
        // Keep track of the last date for an ordering test.
        var lastDate: Date? = nil
        // Iterate over all events
        for try await event in logbook {
            // Ensure this event is also in the randomEvents set.
            XCTAssertTrue(randomEvents.contains(event))
            if let lastDate = lastDate {
                // Ensure this event is newer than the last.
                XCTAssertTrue(lastDate <= event.date)
            }
            // Store this event's date to check the next event's ordering.
            lastDate = event.date
        }
        // Iterate over all randomly generated events
        for event in randomEvents {
            // Ensure the logbook actually contains all of those events.
            let contains = try await logbook.contains(event)
            XCTAssertTrue(contains)
        }
    }
    
    /// Asserts initalizing a logbook with a new path creates the file.
    func testInitializationWithNoFile() async throws {
        let logbook = try Logbook(location: testFilePath)
        var iterator = logbook.makeAsyncIterator()
        let isEmpty = try await iterator.next() == nil
        XCTAssertTrue(isEmpty)
    }
    
    /// Asserts initializing a logbook with an existing logbook file loads the data as expected.
    func testInitializationWithFile() async throws {
        let testEvent = Event()
        let events = [testEvent]
        try JSONEncoder().encode(events).write(to: testFileURL)
        let logbook = try Logbook(location: testFilePath)
        let containsEvent = try await logbook.contains(testEvent)
        XCTAssertTrue(containsEvent)
    }
    
    // MARK: Mutation & Ordering
    
    /// Asserts events inserted using `insert(event:)` are reflected in the `events` dictionary.
    func testUpdateEvent() async throws {
        let event = Event()
        let logbook = try Logbook(location: testFilePath)
        let updatedEvent = await logbook.update(event: event)
        XCTAssertNil(updatedEvent)
        let retrievedEvent = await logbook.event(withID: event.id)
        XCTAssertEqual(event, retrievedEvent)
    }
    
    /// Asserts `remove(eventWithID eventID:)` removes the specified event as expected.
    func testRemoveEvent() async {
        let event = Event()
        let logbook = Logbook(location: FilePath("/dev/null"), events: [event])
        let removedEvent = await logbook.remove(eventWithID: event.id)
        XCTAssertEqual(event, removedEvent)
        let retrievedEvent = await logbook.event(withID: event.id)
        XCTAssertNil(retrievedEvent)
    }
    
    /// Asserts requesting events within an interval returns the expected events.
    func testDateSearch() async throws {
        let events = [
            Event(date: Date(timeIntervalSince1970: 0)),
            Event(date: Date(timeIntervalSince1970: 1)),
            Event(date: Date(timeIntervalSince1970: 2)),
            Event(date: Date(timeIntervalSince1970: 3)),
        ]
        let logbook = Logbook(location: FilePath("/dev/null"), events: events)
        let searchInterval = DateInterval(start: Date(timeIntervalSince1970: 0), duration: 2)
        let retrievedEvents = try await logbook.events(intersecting: searchInterval)
        XCTAssertEqual(Array(events[0...2]), retrievedEvents)
    }
}
