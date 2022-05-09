//
//  Equipment.swift
//  
//
//  Created by Christopher Richez on 5/9/22.
//

import OrderedCollections

/// An aircraft or simulator in which an event is performed.
public struct Equipment {
    /// The unique identifier for this equipment.
    public let id: String
    
    /// The tags defined by the user to describe this equipment.
    public let tags: OrderedSet<String>
    
    /// Initializes a new equipment.
    public init(id: String = "", tags: OrderedSet<String> = []) {
        self.id = id
        self.tags = tags
    }
}
