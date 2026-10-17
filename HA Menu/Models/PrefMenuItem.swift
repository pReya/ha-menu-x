//
//  PrefMenuItem.swift
//  HA Menu X
//
//  Created by Andrew Jackson on 28/01/2020.
//  Copyright © 2020 CodeChimp. All rights reserved.
//

import Foundation

enum itemTypes: String, Codable {
    case Domain = "Domain"
    case Group = "Group"
    case Area = "Area"
}

struct PrefMenuItem : Codable {
    var entityId: String
    var itemType: itemTypes
    var subMenu: Bool
    var enabled: Bool
    var friendlyName: String
    var index: Int = 0

    private enum CodingKeys: String, CodingKey {
        case entityId, friendlyName, itemType, subMenu, enabled
    }

    // Unique across item types (a group and an area can share the same id)
    var orderKey: String {
        return "\(itemType.rawValue):\(entityId)"
    }
}
