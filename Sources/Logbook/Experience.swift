//
//  Experience.swift
//  
//
//  Created by Christopher Richez on 5/9/22.
//

/// Experience acquired during an event.
public enum Experience {
    case text(String)
    case count(Int)
    case time(Double)
    case list([String])
    case flag(Bool)
}
