//
//  Item.swift
//  Quarry
//
//  Created by Rohan George on 11/8/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
