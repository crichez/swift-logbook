//
//  Event.swift
//
//
//  Created by Christopher Richez on 5/9/22
//

import Foundation
import OrderedCollections

/// A flight, simulator or ground event.
///
/// Events are defined by their `date`, `equipment` and zero or more optional fields.
public struct Event {
    /// The date this event took place.
    public let date: Date
    
    /// The aircraft or simulator used, if any.
    public let equipment: Equipment?
    
    /// The experience acquired during this event.
    public let experience: OrderedDictionary<String, Experience>
    
    /// User comments.
    public let comments: String
    
    /// The endorsement to seal this entry, if applicable.
    public let endorsement: Endorsement?
    
    /// Initializes a new event.
    init(
        date: Date = Date(),
        equipment: Equipment? = nil,
        experience: OrderedDictionary<String, Experience> = [:],
        comments: String = "",
        endorsement: Endorsement? = nil
    ) {
        self.date = date
        self.equipment = equipment
        self.experience = experience
        self.comments = comments
        self.endorsement = endorsement
    }
}
