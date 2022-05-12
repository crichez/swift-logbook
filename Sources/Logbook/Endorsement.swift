//
//  Endorsement.swift
//  
//
//  Created by Christopher Richez on 5/9/22.
//

import Foundation

/// An endorsement attached to an event to prevent it from farther modification.
public struct Endorsement: Hashable, Codable {
    /// The endorser's unique identifier.
    public let endorser: String
    
    /// The endorser's signature data.
    public let signature: Data
    
    /// Initializes a new endorsement.
    public init(endorser: String = "", signature: Data = Data()) {
        self.endorser = endorser
        self.signature = signature
    }
}
