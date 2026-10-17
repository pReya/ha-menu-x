//
//  Preferences.swift
//  HA Menu X
//
//  Created by Andrew Jackson on 04/11/2018.
//  Copyright © 2018 CodeChimp. All rights reserved.
//

import Foundation
import ServiceManagement

struct Preferences {

    var settingsVersion: Int {
        get {
            return UserDefaults.standard.integer(forKey: "settingsVersion")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "settingsVersion")
            UserDefaults.standard.synchronize()
        }
    }

    var server: String {
        get {
            var serverUrl = UserDefaults.standard.string(forKey: "server") ?? ""
            // Remove trailing slash
            if (serverUrl.hasSuffix("/")) {
                serverUrl.remove(at: serverUrl.index(before: serverUrl.endIndex))
            }
            return serverUrl
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespaces), forKey: "server")
            UserDefaults.standard.synchronize()
        }
    }

    var token: String {
        get {
            return UserDefaults.standard.string(forKey: "token") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespaces), forKey: "token")
            UserDefaults.standard.synchronize()
        }
    }

    // Start at login, read from and written to the system's login items so it stays in sync with System Settings
    var launch: Bool {
        get {
            return SMAppService.mainApp.status == .enabled
        }
        set {
            let service = SMAppService.mainApp
            do {
                if newValue && service.status != .enabled {
                    try service.register()
                    UserDefaults.standard.set(Bundle.main.bundlePath, forKey: "login_item_path")
                }
                else if !newValue && service.status != .notRegistered {
                    try service.unregister()
                }
            }
            catch {
                print("Unable to change login item: \(error.localizedDescription)")
            }

            // Turned off by the user in System Settings before, it has to be turned on there again
            if newValue && service.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }

    var groupList: String {
        get {
            var groupList = UserDefaults.standard.string(forKey: "group") ?? ""

            // remove all_* groups that are deprecated, we use domains now
            groupList = groupList.replacingOccurrences(of: "all_lights", with: "")
            groupList = groupList.replacingOccurrences(of: "all_switches", with: "")
            groupList = groupList.replacingOccurrences(of: "all_automations", with: "")

            // replace spaces with commas, remove duplicated commas
            groupList = groupList.replacingOccurrences(of: " ", with: ",")
            groupList = groupList.replacingOccurrences(of: ",,", with: ",")

            // remove leading/trailing commas
            if (groupList.hasPrefix(",")) {
                groupList = String(groupList.dropFirst())
            }
            if (groupList.hasSuffix(",")) {
                groupList = String(groupList.dropLast())
            }

            return (groupList)
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespaces), forKey: "group")
            UserDefaults.standard.synchronize()
        }
    }

    var groups: [String] {

        var groupArray = [String]()

        // create array of groups, reverse order
        groupArray = self.groupList.components(separatedBy: ",")
        groupArray.reverse()

        return groupArray
    }

    var domainLights: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "domain_lights")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "domain_lights")
            UserDefaults.standard.synchronize()
        }
    }

    var domainSwitches: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "domain_switches")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "domain_switches")
            UserDefaults.standard.synchronize()
        }
    }

    var domainAutomations: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "domain_automations")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "domain_automations")
            UserDefaults.standard.synchronize()
        }
    }

    var domainInputBooleans: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "domain_inputbooleans")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "domain_inputbooleans")
            UserDefaults.standard.synchronize()
        }
    }

    var domainInputSelects: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "domain_inputselects")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "domain_inputselects")
            UserDefaults.standard.synchronize()
        }
    }

    var domainScenes: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "domain_scenes")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "domain_scenes")
            UserDefaults.standard.synchronize()
        }
    }

    var domainScripts: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "domain_scripts")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "domain_scripts")
            UserDefaults.standard.synchronize()
        }
    }
    
    var domainCovers: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "domain_covers")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "domain_covers")
            UserDefaults.standard.synchronize()
        }
    }
    
    var domainButtons: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "domain_buttons")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "domain_buttons")
            UserDefaults.standard.synchronize()
        }
    }
    
    var domainInputButtons: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "domain_inputbuttons")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "domain_inputbuttons")
            UserDefaults.standard.synchronize()
        }
    }

    var hiddenEntities: [String] {
        get {
            return UserDefaults.standard.stringArray(forKey: "hidden_entities") ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "hidden_entities")
            UserDefaults.standard.synchronize()
        }
    }

    var menuItems: [PrefMenuItem] {
        get {
            var decodedResponse = [PrefMenuItem]()

            // Check if string empty
            var jsonString = UserDefaults.standard.string(forKey: "menu_items") ?? ""

            if !jsonString.isEmpty {
                // Got JSON
                do {
                    let jsonData = jsonString.data(using: String.Encoding.utf8, allowLossyConversion: false)
                    decodedResponse = try JSONDecoder().decode([PrefMenuItem].self, from: jsonData!)

                    // Upgrade with any new domains
                    if !domainExists(domain: "scene", prefs: decodedResponse) {
                        decodedResponse.append(PrefMenuItem(entityId: "scene", itemType: itemTypes.Domain, subMenu: true, enabled: domainScenes, friendlyName: "Scenes"))
                    }

                    if !domainExists(domain: "script", prefs: decodedResponse) {
                        decodedResponse.append(PrefMenuItem(entityId: "script", itemType: itemTypes.Domain, subMenu: true, enabled: domainScenes, friendlyName: "Scripts"))
                    }
                    
                    if !domainExists(domain: "cover", prefs: decodedResponse) {
                        decodedResponse.append(PrefMenuItem(entityId: "cover", itemType: itemTypes.Domain, subMenu: true, enabled: domainCovers, friendlyName: "Covers"))
                    }

                    if !domainExists(domain: "button", prefs: decodedResponse) {
                        decodedResponse.append(PrefMenuItem(entityId: "button", itemType: itemTypes.Domain, subMenu: true, enabled: domainButtons, friendlyName: "Buttons"))
                    }
                    
                    if !domainExists(domain: "input_button", prefs: decodedResponse) {
                        decodedResponse.append(PrefMenuItem(entityId: "input_button", itemType: itemTypes.Domain, subMenu: true, enabled: domainButtons, friendlyName: "Input Buttons"))
                    }
                    
                    return decodedResponse
                }
                catch {
                    // Something odd with json, blank it out and default
                    jsonString = ""
                }
            }

            if jsonString.isEmpty {
                // Init Domains
                decodedResponse.append(PrefMenuItem(entityId: "light", itemType: itemTypes.Domain, subMenu: true, enabled: domainLights, friendlyName: "Lights"))

                decodedResponse.append(PrefMenuItem(entityId: "switch", itemType: itemTypes.Domain, subMenu: true, enabled: domainSwitches, friendlyName: "Switches"))

                decodedResponse.append(PrefMenuItem(entityId: "automation", itemType: itemTypes.Domain, subMenu: true, enabled: domainAutomations, friendlyName: "Automations"))

                decodedResponse.append(PrefMenuItem(entityId: "input_boolean", itemType: itemTypes.Domain, subMenu: true, enabled: domainInputBooleans, friendlyName: "Input Booleans"))

                decodedResponse.append(PrefMenuItem(entityId: "input_select", itemType: itemTypes.Domain, subMenu: true, enabled: domainInputSelects, friendlyName: "Input Selects"))

                decodedResponse.append(PrefMenuItem(entityId: "scene", itemType: itemTypes.Domain, subMenu: true, enabled: domainScenes, friendlyName: "Scenes"))

                decodedResponse.append(PrefMenuItem(entityId: "script", itemType: itemTypes.Domain, subMenu: true, enabled: domainScripts, friendlyName: "Scripts"))
                
                decodedResponse.append(PrefMenuItem(entityId: "cover", itemType: itemTypes.Domain, subMenu: true, enabled: domainCovers, friendlyName: "Covers"))

                decodedResponse.append(PrefMenuItem(entityId: "button", itemType: itemTypes.Domain, subMenu: true, enabled: domainButtons, friendlyName: "Buttons"))
                
                decodedResponse.append(PrefMenuItem(entityId: "input_button", itemType: itemTypes.Domain, subMenu: true, enabled: domainInputButtons, friendlyName: "Input Buttons"))
                
                // Init Groups from old setting
                for group in groups {
                    decodedResponse.append(PrefMenuItem(entityId: group, itemType: itemTypes.Group, subMenu: false, enabled: true, friendlyName: ""))
                }
                
                return decodedResponse
            }

            return decodedResponse
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                let dataString = String(data: data, encoding: .utf8)!
                UserDefaults.standard.set(dataString, forKey: "menu_items")

                settingsVersion = 2
            }
            catch {
                // Error encoding json, don't write new value
            }
        }
    }

    private func domainExists(domain: String, prefs: [PrefMenuItem]) -> Bool {
        var foundDomain = false

        for prefMenuItem in prefs {
            if prefMenuItem.entityId == domain {
                foundDomain = true
                break
            }
        }

        return foundDomain
    }

    // Returns the stored menu items in display order with current friendly names,
    // dropping groups/areas that no longer exist and appending new ones (disabled).
    // Pass areas as nil when they could not be loaded, stored area items are then kept as they are.
    func menuItemsWithFriendlyNames(groups: [HaEntity], areas: [HaArea]?) -> [PrefMenuItem] {
        var completedItems = [PrefMenuItem]()
        var seenKeys = Set<String>()

        for item in menuItems {
            var completedItem = item

            switch item.itemType {
            case itemTypes.Group:
                // Check if still a group
                guard let group = getGroup(groups: groups, entityId: "group." + item.entityId) else {
                    continue
                }
                completedItem.friendlyName = group.friendlyName
            case itemTypes.Area:
                if let areas = areas {
                    // Check if still an area
                    guard let area = areas.first(where: {$0.id == item.entityId}) else {
                        continue
                    }
                    completedItem.friendlyName = area.name
                }
            case itemTypes.Domain:
                break
            }

            if seenKeys.insert(completedItem.orderKey).inserted {
                completedItems.append(completedItem)
            }
        }

        // Add missing groups
        for group in groups {
            let item = PrefMenuItem(entityId: group.entityIdNoPrefix, itemType: itemTypes.Group, subMenu: false, enabled: false, friendlyName: group.friendlyName)
            if seenKeys.insert(item.orderKey).inserted {
                completedItems.append(item)
            }
        }

        // Add missing areas, as submenus since they are usually used as rooms
        for area in areas ?? [] {
            let item = PrefMenuItem(entityId: area.id, itemType: itemTypes.Area, subMenu: true, enabled: false, friendlyName: area.name)
            if seenKeys.insert(item.orderKey).inserted {
                completedItems.append(item)
            }
        }

        for index in completedItems.indices {
            completedItems[index].index = index + 1
        }

        return completedItems
    }

    // Custom order of entities within a menu item (domain, group or area), keyed by PrefMenuItem.orderKey.
    // Empty means the default order.
    func entityOrder(for key: String) -> [String] {
        let orders = UserDefaults.standard.dictionary(forKey: "entity_order") as? [String: [String]] ?? [:]
        return orders[key] ?? []
    }

    func setEntityOrder(_ entityIds: [String], for key: String) {
        var orders = UserDefaults.standard.dictionary(forKey: "entity_order") as? [String: [String]] ?? [:]
        if entityIds.isEmpty {
            orders.removeValue(forKey: key)
        } else {
            orders[key] = entityIds
        }
        UserDefaults.standard.set(orders, forKey: "entity_order")
        UserDefaults.standard.synchronize()
    }

    private func getGroup(groups: [HaEntity], entityId: String) -> HaEntity? {
        for g in groups {
            if g.entityId == entityId {
                return g
            }
        }
        return nil
    }

}
