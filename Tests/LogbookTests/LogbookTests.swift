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

#if os(Linux)
import Glibc
#elseif os(Windows)
import ucrt
#elseif os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#endif

/// A test suite for each method in the `Logbook` class.
final class LogbookTests: XCTestCase {
    
    // MARK: File Management
    
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
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
    #endif
    
    /// The path to the test file.
    lazy var testFilePath: FilePath = {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        FilePath(testFileURL.path)
        #elseif os(Linux)
        FilePath("/tmp/testLogbook.json")
        #elseif os(Windows)
        let tempFileNameBuffer = UnsafeMutablePointer<CInterop.PlatformChar>.allocate(capacity: 12)
        guard _wmktemp_s(tempFileNameBuffer, 12) == 0 else {
            let error = Errno(rawValue: errno)
            fatalError("error getting temp file name: \(error)")
        }
        return FilePath(platformString: tempFileNameBuffer)
        #endif
    }()
    
    /// Removes the file at the specified path, or throws the appropriate `Errno`.
    private func removeFile(at path: FilePath) throws {
        do {
            try path.withPlatformString { path in
                #if os(Windows)
                guard _wremove(path) == 0 else {
                    throw Errno(rawValue: errno)
                }
                #else
                guard unlink(path) == 0 else {
                    throw Errno(rawValue: errno)
                }
                #endif
            }
        }
    }
    
    /// Removes all test data to avoid test contamination
    override func setUpWithError() throws {
        do {
            try removeFile(at: testFilePath)
        } catch Errno.noSuchFileOrDirectory {
            // Do nothing, this is fine.
        }
    }
    
    #if os(Windows)
    deinit {
        testFilePath.withPlatformString { path in
            guard _wremove(path) == 0 else {
                print("the file at \(path) couldn't be removed, please do so manually.")
                return
            }
        }
    }
    #endif
    
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
        let encodedEvents = try JSONEncoder().encode(events)
        try encodedEvents.withUnsafeBytes { bytesToWrite in
            let file = try FileDescriptor.open(
                testFilePath, .writeOnly,
                options: [.create, .truncate],
                permissions: .ownerReadWriteExecute)
            try file.closeAfter {
                let bytesWritten = try file.write(bytesToWrite)
                guard bytesWritten == bytesToWrite.count else {
                    XCTFail("didn't write the whole file!")
                    return
                }
            }
        }
        let logbook = try Logbook(location: testFilePath)
        let containsEvent = try await logbook.contains(testEvent)
        XCTAssertTrue(containsEvent)
    }
    
    // MARK: Mutation & Ordering
    
    /// Asserts events inserted using `update(event:)` are retrievable by ID and by date.
    func testInsertEvent() async throws {
        let event = Event()
        let logbook = Logbook(location: testFilePath, events: [])
        let existingEvent = await logbook.update(event: event)
        XCTAssertNil(existingEvent)
        let retrievedEvent = await logbook.event(withID: event.id)
        XCTAssertEqual(event, retrievedEvent)
        let dateRetrievedEvents = await logbook[event.date...event.date]
        XCTAssertEqual(dateRetrievedEvents.first, event)
    }

    /// Asserts updating an event's date using `update(event:)` makes the event retrievable by ID
    /// and by date.
    func testUpdateEventWithNewDate() async throws {
        let originalEvent = Event()
        let logbook = Logbook(location: testFilePath, events: [])
        let existingEvent = await logbook.update(event: originalEvent)
        XCTAssertNil(existingEvent)
        let newDate = Date()
        let updatedEvent = Event(id: originalEvent.id, date: newDate)
        let replacedEvent = await logbook.update(event: updatedEvent)
        XCTAssertEqual(originalEvent, replacedEvent)
        let retrievedEvent = await logbook.event(withID: originalEvent.id)
        XCTAssertEqual(updatedEvent, retrievedEvent)
        let correctDateRetrievedEvents = await logbook[newDate...]
        XCTAssertEqual(correctDateRetrievedEvents.first, updatedEvent)
        let incorrectDateRetrievedEvents = await logbook[..<newDate]
        XCTAssertTrue(incorrectDateRetrievedEvents.isEmpty)
    }

    func testUpdateEventWithOldDate() async throws {
        let originalEvent = Event()
        let logbook = Logbook(location: testFilePath, events: [])
        let existingEvent = await logbook.update(event: originalEvent)
        XCTAssertNil(existingEvent)
        let updatedEvent = Event(id: originalEvent.id, date: originalEvent.date, comments: "test")
        let replacedEvent = await logbook.update(event: updatedEvent)
        XCTAssertEqual(originalEvent, replacedEvent)
        let retrievedEvent = await logbook.event(withID: originalEvent.id)
        XCTAssertEqual(updatedEvent, retrievedEvent)
        let dateRetrievedEvents = await logbook[originalEvent.date...originalEvent.date]
        XCTAssertEqual(dateRetrievedEvents.first, updatedEvent)
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
        let date0 = Date(timeIntervalSinceReferenceDate: 0)
        let date1 = Date(timeIntervalSinceReferenceDate: 1)
        let date2 = Date(timeIntervalSinceReferenceDate: 2)
        let date3 = Date(timeIntervalSinceReferenceDate: 3)
        let events = [
            Event(date: date0),
            Event(date: date1),
            Event(date: date2),
            Event(date: date3),
        ]
        let logbook = Logbook(location: FilePath("/dev/null"), events: events)
        // Range
        let rangeEvents = await logbook[date0..<date3]
        XCTAssertEqual(Array(events[0..<3]), rangeEvents)
        // ClosedRange
        let closedRangeEvents = await logbook[date1...date3]
        XCTAssertEqual(Array(events[1...3]), closedRangeEvents)
        // PartialRangeUpTo
        let partialRangeUpToEvents = await logbook[..<date2]
        XCTAssertEqual(Array(events[..<2]), partialRangeUpToEvents)
        // PartialRangeThrough
        let partialRangeThroughEvents = await logbook[...date2]
        XCTAssertEqual(Array(events[...2]), partialRangeThroughEvents)
    }

    /// Asserts requesting all events with the specified experience key yields expected events.
    func testExperienceSearch() async {
        let date = Date()
        let events = [
            Event(date: date, experience: ["PIC": .time(3600)]),
            Event(date: date, experience: ["PIC": .time(4800), "SIC": .time(4800)]),
            Event(date: date, experience: ["Landings": .count(1)]),
        ]
        let logbook = Logbook(location: testFilePath, events: events)
        let eventsWithPIC = await logbook.events(withExperience: "PIC")
        XCTAssertEqual(eventsWithPIC, Array(events[0...1]))
        let eventsWithSIC = await logbook.events(withExperience: "SIC")
        XCTAssertEqual(eventsWithSIC, [events[1]])
        let eventsWithLandings = await logbook.events(withExperience: "Landings")
        XCTAssertEqual(eventsWithLandings, [events[2]])
        let eventsWithUnnamedExperience = await logbook.events(withExperience: "")
        XCTAssertTrue(eventsWithUnnamedExperience.isEmpty)
    }

    /// Asserts requesting events with a specific experience key within a provided
    /// date range returns the expected events.
    func testDateAndExperienceSearch() async {
        let refDate = Date(timeIntervalSinceReferenceDate: 0)
        let events = [
            Event(date: refDate, experience: ["Total": .time(4000)]),
            Event(date: refDate + 1, experience: ["Total": .time(1000)]),
            Event(date: refDate + 1, experience: [:]),
        ]
        let logbook = Logbook(location: testFilePath, events: events)
        let oldEventsWithPIC = await logbook.events(
            withExperience: "Total", 
            within: refDate...refDate)
        XCTAssertEqual(oldEventsWithPIC, [events[0]])
        let allEventsWithPIC = await logbook.events(
            withExperience: "Total", 
            within: refDate...)
        XCTAssertEqual(allEventsWithPIC, Array(events[0...1]))
    }
}
