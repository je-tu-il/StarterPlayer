//
//  Item.swift
//  FingerPick
//
//  Created by Rork on May 31, 2026.
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
