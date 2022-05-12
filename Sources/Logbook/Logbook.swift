//
//  Logbook.swift
//  
//
//  Created by Christopher Richez on 5/9/22.
//

import Foundation
import SystemPackage
import SortedCollections
import OrderedCollections

/// The object that manages storage of events.
public actor Logbook {
    /// The location of the logbook file.
    let location: FilePath
    
    /// The events in this logbook.
    var eventsByID: [UUID: Event]
    
    /// A sorted dictionary where keys are event dates,
    /// and values are all the event IDs at that date.
    typealias DateIndex = SortedDictionary<Date, OrderedSet<UUID>>
    
    /// Event IDs ordered by date.
    var eventIDsByDate: DateIndex
    
    /// Initializes a logbook with the provided write location and events.
    init<S: Sequence>(location: FilePath, events: S) where S.Element == Event {
        self.location = location
        let (eventsByID, eventIDsByDate) = Logbook.index(events: events)
        self.eventsByID = eventsByID
        self.eventIDsByDate = eventIDsByDate
    }
}

// MARK: File Management

extension Logbook {
    /// Creates an empty logbook file at the specified location.
    static func createEmptyFile(at location: FilePath) throws {
        let file = try FileDescriptor.open(
            location, .readWrite,
            options: [.create],
            permissions: .ownerReadWriteExecute)
        try file.close()
    }
    
    /// Reads the events at the specified logbook file location.
    static func readEvents(at location: FilePath) throws -> [Event] {
        let file = try FileDescriptor.open(location, .readOnly)
        return try file.closeAfter {
            let size = try file.seek(offset: 0, from: .end)
            let buffer = UnsafeMutableRawBufferPointer.allocate(
                byteCount: Int(size),
                alignment: 1)
            guard try file.read(fromAbsoluteOffset: 0, into: buffer) == Int(size) else {
                throw Errno.ioError
            }
            let decoder = JSONDecoder()
            let data = Data(bytes: UnsafeRawBufferPointer(buffer).baseAddress!, count: Int(size))
            return try decoder.decode(Array<Event>.self, from: data)
        }
    }
    
    /// Indexes the provided events into the dictionary pair.
    static func index<S: Sequence>(events: S) -> ([UUID: Event], DateIndex)
    where S.Element == Event {
        var eventsByID: [UUID: Event] = [:]
        var eventIDsByDate: DateIndex = [:]
        for event in events {
            eventsByID[event.id] = event
            if eventIDsByDate[event.date] == nil {
                eventIDsByDate[event.date] = [event.id]
            } else {
                eventIDsByDate[event.date]!.append(event.id)
            }
        }
        return (eventsByID, eventIDsByDate)
    }
    
    /// Initializes a logbook at the specified location,
    /// optionally creating the file if it doesn't exist.
    public convenience init(location: FilePath) throws {
        do {
            let events = try Logbook.readEvents(at: location)
            self.init(location: location, events: events)
        } catch Errno.noSuchFileOrDirectory {
            try Logbook.createEmptyFile(at: location)
            self.init(location: location, events: [])
        }
    }
    
    // Overwrites the logbook file with the contents of the events dictionary.
    public func save() async throws {
        let file = try FileDescriptor.open(
            location, .writeOnly,
            options: [.create, .truncate],
            permissions: .ownerReadWriteExecute)
        let data = try JSONEncoder().encode(Array(eventsByID.values))
        try file.closeAfter {
            guard try file.writeAll(data) == data.count else { throw Errno.ioError }
        }
    }
}

// MARK: Mutation

extension Logbook {
    /// Removes the provided event ID from the `eventIDsByDate` dictionary.
    func clearIndex(eventID: UUID, lastKnownDate: Date) {
        // Try removing this ID at the last known date.
        if eventIDsByDate[lastKnownDate]?.remove(eventID) == nil {
            // If that doesn't work, search the entire dictionary for the old date.
            if let oldPair = eventIDsByDate.first(where: { date, ids in
                ids.contains(eventID)
            }) {
                // Remove the ID from its old date.
                eventIDsByDate[oldPair.key]!.remove(eventID)
            }
        }
    }
    
    /// Updates the provided event in the logbook.
    ///
    /// If an event with that ID didn't exist before, it is inserted.
    ///
    /// - Complexity: O(n)
    ///
    /// - Parameter event: the new or mutated event to update the logbook for
    ///
    /// - Returns: If the event already existed, the old event. Otherwise `nil`.
    @discardableResult public func update(event: Event) -> Event? {
        if let oldValue = eventsByID.updateValue(event, forKey: event.id) {
            // This event ID existed before, so this in an update.
            clearIndex(eventID: event.id, lastKnownDate: oldValue.date)
            // Return the old event.
            return oldValue
        } else {
            // This event ID didn't exist before, so this is an insertion.
            // Add the new ID to the date keyed dictionary.
            if eventIDsByDate[event.date] == nil {
                eventIDsByDate[event.date] = [event.id]
            } else {
                eventIDsByDate[event.date]!.append(event.id)
            }
            // Return nil to signal this was an insertion.
            return nil
        }
    }
    
    /// Removes the event with the provided ID from the logbook.
    ///
    /// - Parameter eventID: the ID of the event to remove.
    ///
    /// - Returns: If an event was removed, the removed event. Otherwise `nil`.
    @discardableResult public func remove(eventWithID eventID: UUID) -> Event? {
        if let removedEvent = eventsByID.removeValue(forKey: eventID) {
            // The event was removed, so we need to remove it from the date-keyed dictionary.
            clearIndex(eventID: eventID, lastKnownDate: removedEvent.date)
            // Return the removed event.
            return removedEvent
        } else {
            // The event didn't exist, return nil.
            return nil
        }
    }
}

// MARK: Sequence

extension Logbook: AsyncSequence {
    public typealias Element = Event
    public typealias AsyncIterator = EventIterator
    
    /// An iterator that returns all events in chronological order.
    public struct EventIterator: AsyncIteratorProtocol {
        let logbook: Logbook
        
        var eventIDsByDate: DateIndex.Iterator? = nil
        var eventIDIterator: OrderedSet<UUID>.Iterator? = nil
        var eventsByID: [UUID: Event]? = nil
        
        public init(logbook: Logbook) {
            self.logbook = logbook
        }
        
        public mutating func next() async throws -> Event? {
            guard eventIDsByDate != nil && eventsByID != nil else {
                self.eventIDsByDate = await logbook.eventIDsByDate.makeIterator()
                self.eventsByID = await logbook.eventsByID
                return try await next()
            }
            // Check whether we are still working through a set of IDs.
            if eventIDIterator != nil {
                // If so, get the next ID and its associated event.
                if let nextID = eventIDIterator!.next(), let nextEvent = eventsByID![nextID] {
                    // If we could find one, return it.
                    return nextEvent
                } else {
                    // If we couldn't find one, unset the eventIDIteartor and continue.
                    eventIDIterator = nil
                    return try await next()
                }
            } else {
                // If not, move to the next date.
                if let eventIDs = eventIDsByDate!.next() {
                    self.eventIDIterator = eventIDs.value.makeIterator()
                    return try await next()
                } else {
                    return nil
                }
            }
        }
    }
    
    /// Makes an iterator that returns all events in chronological order.
    nonisolated public func makeAsyncIterator() -> EventIterator {
        EventIterator(logbook: self)
    }
}

// MARK: Retrieval

extension Logbook {
    /// Returns the event with the specified ID, or `nil` if none exists.
    public func event(withID id: UUID) -> Event? {
        eventsByID[id]
    }
    
    /// Returns the events within the specified interval.
    public func events(intersecting interval: DateInterval) async throws -> [Event] {
        var matchingEvents: [Event] = []
        for try await event in self {
            if event.date < interval.start {
                continue
            } else if interval.contains(event.date) {
                matchingEvents.append(event)
            } else {
                break
            }
        }
        return matchingEvents
    }
}
