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
    
    /// Initializes a logbook by opening the provided logbook file.
    public init(location: FilePath) {
        self.location = location
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
}
