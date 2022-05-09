//
//  Logbook.swift
//  
//
//  Created by Christopher Richez on 5/9/22.
//

import SystemPackage
import FowlerNollVo

/// The object that manages reading and writing of a logbook file.
public class Logbook {
    /// The path to the logbook file.
    public let location: FilePath
    
    /// The current capacity of the event table.
    public var capacity: Int
    
    /// The current number of events in the logbook file.
    public var count: Int
    
    /// Initializes a logbook by opening the provided logbook file.
    public init(location: FilePath) throws {
        self.location = location
        do {
            let (capacity, count) = try Logbook.readExistingMetadata(at: location)
            self.capacity = capacity
            self.count = count
        } catch Errno.noSuchFileOrDirectory {
            // Create an empty logbook file.
            try Logbook.createEmptyFile(at: location)
            self.capacity = 256
            self.count = 16 + 256 * 8
        }
    }
}

// MARK: File Initialization

extension Logbook {
    /// Creates or overwrites the file at the specified location with an empty logbook file.
    static func createEmptyFile(at location: FilePath) throws {
        /// The initial capacity of the logbook file table.
        let capacity = 256
        /// The initial size of the logbook file as determined by its capacity.
        let size = 16 + capacity * 8
        // Try opening, truncating or creating the file.
        let file = try FileDescriptor.open(
            location, .readWrite,
            options: [.create, .truncate],
            permissions: .ownerReadWriteExecute)
        // Unconditionally close the file before returning
        try file.closeAfter {
            let bytesWritten = try file.writeAll([UInt8](repeating: 0, count: size))
            guard bytesWritten == size else { throw Errno.ioError }
            try withUnsafeBytes(of: capacity) { capacityBytes in
                let capacityBytesWritten = try file.write(toAbsoluteOffset: 0, capacityBytes)
                guard capacityBytesWritten == 8 else { throw Errno.ioError }
            }
        }
    }
    
    /// Reads the existing capacity and count metadata at the provided location.
    static func readExistingMetadata(at location: FilePath) throws -> (capacity: Int, count: Int) {
        let file = try FileDescriptor.open(location, .readOnly)
        return try file.closeAfter {
            // Read the capacity
            let capacityBytes = UnsafeMutableRawBufferPointer.allocate(byteCount: 8, alignment: 1)
            let capacityBytesRead = try file.read(into: capacityBytes)
            guard capacityBytesRead == 8 else { throw Errno.ioError }
            let capacity = capacityBytes.load(as: Int.self)
            // Read the count
            let countBytes = UnsafeMutableRawBufferPointer.allocate(byteCount: 8, alignment: 1)
            let countBytesRead = try file.read(into: countBytes)
            guard countBytesRead == 8 else { throw Errno.ioError }
            let count = countBytes.load(as: Int.self)
            // Return the read data
            return (capacity, count)
        }
    }
}
