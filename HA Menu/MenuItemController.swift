//
//  MenuItemController
//  HA Menu X
//
//  Created by Andrew Jackson on 07/11/2018.
//  Copyright © 2018 CodeChimp. All rights reserved.
//

import Foundation
import Cocoa
import FeedKit

final class MenuItemController: NSObject, NSMenuDelegate {

    var haService = HaService.shared
    var prefs = Preferences()
    var haStates : [HaState]?
    var groups = [HaEntity]()
    var menuItems = [PrefMenuItem]()
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let menu = NSMenu()
    
    var preferences: Preferences

    let menuItemPreferences = 994
    let menuItemAbout = 995
    let menuItemTypeTopLevel = 996
    let menuItemTypeInfo = 997
    let menuItemTypeHidden = 998
    let menuItemTypeError = 999

    let releasesFeedURL = URL(string: "https://github.com/pReya/ha-menu-x/releases.atom")!
    let releasesURL = URL(string: "https://github.com/pReya/ha-menu-x/releases")!
    
    override init() {
        preferences = Preferences()
        
        super.init()

        statusItem.autosaveName = "org.codechimp.hamenu.menu"
        
        if let statusButton = statusItem.button {
            #if DEBUG
            let icon = NSImage(named: "StatusBarButtonImageDebug")
            #else
            let icon = NSImage(named: "StatusBarButtonImage")
            icon?.isTemplate = true // best for dark mode
            #endif

            statusButton.image = icon
            //            button.action = #selector(self.statusBarButtonClicked(sender:))
            statusButton.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        buildStaticMenu()
        
        statusItem.menu = menu
        
        menu.delegate = self
    }

    public func menuWillOpen(_ menu: NSMenu){
        // Dirty fix for Sonoma which doesn't like menu items being changed during WillOpen
        DispatchQueue.main.async {
            self.removeDynamicMenuItems()

            self.addDynamicMenuItems(){
                result in
                switch result {
                case .success( _):
                    self.checkForUpdate()
                case .failure( _):
                    break
                }
            }
        }
    }
    
    public func menuDidClose(_ menu: NSMenu){
    }
    
    func buildStaticMenu() {

        menu.addItem(NSMenuItem.separator())

        let prefMenu = NSMenuItem(title: "Preferences", action: #selector(openPreferences(sender:)), keyEquivalent: ",")
        prefMenu.tag = menuItemPreferences
        prefMenu.target = self
        menu.addItem(prefMenu)
        
        menu.addItem(NSMenuItem.separator())
        
        let openHaMenu = NSMenuItem(title: "Open Home Assistant", action: #selector(openHA(sender:)), keyEquivalent: "")
        openHaMenu.target = self
        menu.addItem(openHaMenu)
        
        let openAbout = NSMenuItem(title: "About HA Menu X", action: #selector(openAbout(sender:)), keyEquivalent: "")
        openAbout.tag = menuItemAbout
        openAbout.target = self
        menu.addItem(openAbout)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit HA Menu X", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
    }

    @objc func openAppWebsite(sender: NSMenuItem) {
        NSWorkspace.shared.open(releasesURL)
    }

    @objc func openHA(sender: NSMenuItem) {

        if #available(OSX 10.15, *) {
            let url = NSURL(fileURLWithPath: "/Applications/Home Assistant.app", isDirectory: true) as URL

            let path = "/bin"
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.arguments = [path]
            configuration.promptsUserIfNeeded = false

            NSWorkspace.shared.openApplication(at: url,
                                               configuration: configuration) { (app, error) in
                                                if error != nil {
                                                    // Fallback to opening website
                                                    NSWorkspace.shared.open(NSURL(string: self.prefs.server)! as URL)
                                                }
            }

        } else {
            // Fallback on earlier versions
            if !NSWorkspace.shared.launchApplication("Home Assistant") {
                // Fallback to opening website
                NSWorkspace.shared.open(NSURL(string: self.prefs.server)! as URL)
            }

        }

    }


    
    @objc func openAbout(sender: NSMenuItem) {
        let options = [String: Any]()
        NSApp.orderFrontStandardAboutPanel(options)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func openPreferences(sender: NSMenuItem) {

        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        if let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("PrefsWindowController")) as? NSWindowController
        {
            NSApp.runModal(for: windowController.window!)

            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func addDynamicMenuItems(completionHandler: @escaping (Result<Bool, HaService.HaServiceApiError>) -> Void) {
        // Areas need an extra request, only load them when they are shown
        let includeAreas = prefs.menuItems.contains(where: {$0.itemType == itemTypes.Area && $0.enabled})

        haService.getStates(includeAreas: includeAreas) {
            result in
            switch result {
            case .success( _):

                self.groups = self.haService.filterEntities(entityDomain: EntityDomains.groupDomain.rawValue).reversed()

                // Items are inserted at the top of the menu one after another, so add them in reverse
                self.menuItems = self.prefs.menuItemsWithFriendlyNames(groups: self.groups, areas: self.haService.haAreas).reversed()

                // Add Menu Items
                var nextRequiresSeparator = true
                var areasMissing = false
                for menuItem in self.menuItems {
                    if menuItem.itemType == itemTypes.Area && self.haService.haAreas == nil {
                        areasMissing = areasMissing || menuItem.enabled
                        continue
                    }
                    if menuItem.enabled {
                        nextRequiresSeparator = self.addMenuItem(menuItem: menuItem, requiresSeparator: nextRequiresSeparator)
                    }
                }
                if areasMissing {
                    self.addErrorMenuItem(message: "Unable to load areas")
                }
                self.addHiddenEntitiesMenuItem()
                completionHandler(.success(true))

            case .failure(let haServiceApiError):
                switch haServiceApiError {
                case .URLMissing:
                    self.addErrorMenuItem(message: "Server URL missing")
                case .InvalidURL:
                    self.addErrorMenuItem(message: "Invalid URL")
                case .Unauthorized:
                    self.addErrorMenuItem(message: "Unauthorized")
                case .NotFound:
                    self.addErrorMenuItem(message: "Not Found")
                case .UnknownResponse:
                    self.addErrorMenuItem(message: "Unknown Response")
                case .JSONDecodeError:
                    self.addErrorMenuItem(message: "Error Decoding JSON")
                case .UnknownError:
                    self.addErrorMenuItem(message: "Unknown Error (check your server/port)")
                }
                completionHandler(.failure(haServiceApiError))
                break
            }
        }
    }

    func addMenuItem(menuItem: PrefMenuItem, requiresSeparator: Bool) -> Bool {
        if menuItem.itemType == itemTypes.Group && !haService.haStates.contains(where: {$0.entityId == "group.\(menuItem.entityId)"}) {
            self.addErrorMenuItem(message: "Group not found")
            return false
        }

        // Entities are inserted at the top of the menu one after another, so add them in reverse
        let entities = self.haService.entities(for: menuItem)
        self.addMenuItem(menuItem: menuItem, entities: entities.reversed(), requiresSeparator: requiresSeparator)

        return !menuItem.subMenu
    }

    func addMenuItem(menuItem: PrefMenuItem, entities: [HaEntity], requiresSeparator: Bool) {
        DispatchQueue.main.async {

            if entities.count == 0 {
                return
            }

            // Add a seperator before static menu items/previous group
            if (requiresSeparator || !menuItem.subMenu) {
                self.menu.insertItem(NSMenuItem.separator(), at: 0)
            }

            var parent = self.menu


            if menuItem.subMenu {
                let topMenuItem = NSMenuItem()
                topMenuItem.title = menuItem.friendlyName
                topMenuItem.tag = self.menuItemTypeTopLevel
                self.menu.insertItem(topMenuItem, at: 0)

                let subMenu = NSMenu()
                parent = subMenu
                self.menu.setSubmenu(subMenu, for: topMenuItem)
            }

            // Populate menu items
            for haEntity in entities {
                self.addEntityMenuItem(parent: parent, haEntity: haEntity)
            }

        }
    }

    func addEntityMenuItem(parent: NSMenu, haEntity: HaEntity) {

        if haEntity.domainType == EntityDomains.inputSelectDomain {
            let inputSelectMenuItem = NSMenuItem()
            inputSelectMenuItem.title = haEntity.friendlyName
            inputSelectMenuItem.tag = haEntity.type.rawValue
            self.addHideEntityMenuItem(parent: parent, haEntity: haEntity)
            parent.insertItem(inputSelectMenuItem, at: 0)

            let subMenu = NSMenu()
            parent.setSubmenu(subMenu, for: inputSelectMenuItem)

            for option in haEntity.options {
                let optionMenuItem = NSMenuItem()
                optionMenuItem.target = self
                optionMenuItem.title = option
                optionMenuItem.state = ((haEntity.state == option) ? NSControl.StateValue.on : NSControl.StateValue.off)
                optionMenuItem.action = #selector(self.selectInputSelectOption(_ :))
                optionMenuItem.representedObject = haEntity
                optionMenuItem.tag = haEntity.type.rawValue // Tag defines what type of item it is
                subMenu.addItem(optionMenuItem)
            }
        }

        else {
            let menuItem = NSMenuItem()

            menuItem.title = haEntity.friendlyName
            
            if haEntity.domainType == EntityDomains.sceneDomain {
                menuItem.action = #selector(self.turnOnEntity(_:))
                menuItem.state = NSControl.StateValue.off
                menuItem.offStateImage = NSImage(named: "PlayButtonImage")
            }
            else if haEntity.domainType == EntityDomains.scriptDomain {
                menuItem.action = #selector(self.turnOnEntity(_:))
                menuItem.state = NSControl.StateValue.off
                menuItem.offStateImage = NSImage(named: "PlayButtonImage")
            }
            else if haEntity.domainType == EntityDomains.buttonDomain {
                menuItem.action = #selector(self.pressEntity(_:))
                menuItem.state = NSControl.StateValue.off
                menuItem.offStateImage = NSImage(named: "PlayButtonImage")
            }
            else if haEntity.domainType == EntityDomains.inputButtonDomain {
                menuItem.action = #selector(self.pressEntity(_:))
                menuItem.state = NSControl.StateValue.off
                menuItem.offStateImage = NSImage(named: "PlayButtonImage")
            }
            else if haEntity.domainType == EntityDomains.sensorDomain {
                menuItem.title = haEntity.friendlyName + ": " + haEntity.state + haEntity.unitOfMeasurement
                menuItem.action = #selector(self.doNothing(_:))
                menuItem.state = NSControl.StateValue.off
                menuItem.offStateImage = NSImage(named: "BulletImage")
            }
            else if haEntity.domainType == EntityDomains.coverDomain {
                menuItem.action = #selector(self.toggleEntityState(_:))
                menuItem.state = ((haEntity.state == "open" || haEntity.state == "opening") ? NSControl.StateValue.on : NSControl.StateValue.off)
            }
            else {
                menuItem.action = #selector(self.toggleEntityState(_:))
                menuItem.state = ((haEntity.state == "on") ? NSControl.StateValue.on : NSControl.StateValue.off)
            }

            menuItem.target = self
            menuItem.keyEquivalent = ""
            menuItem.representedObject = haEntity
            menuItem.tag = haEntity.type.rawValue // Tag defines what type of item it is
            //        menuItem.image = NSImage(named: "StatusBarButtonImage")
            //        menuItem.offStateImage = NSImage(named: "NSMenuOnStateTemplate")

            self.addHideEntityMenuItem(parent: parent, haEntity: haEntity)
            parent.insertItem(menuItem, at: 0)
        }
    }

    // Alternate of the entity's own menu item, shown in its place while Option is held.
    // Has to be inserted before the entity's item so it ends up directly below it.
    func addHideEntityMenuItem(parent: NSMenu, haEntity: HaEntity) {
        let hideMenuItem = NSMenuItem(title: "Hide " + haEntity.friendlyName, action: #selector(self.hideEntity(_:)), keyEquivalent: "")
        hideMenuItem.target = self
        hideMenuItem.isAlternate = true
        hideMenuItem.keyEquivalentModifierMask = [.option]
        hideMenuItem.representedObject = haEntity
        hideMenuItem.tag = haEntity.type.rawValue // Tag defines what type of item it is

        parent.insertItem(hideMenuItem, at: 0)
    }

    func addHiddenEntitiesMenuItem() {
        DispatchQueue.main.async {
            let hiddenEntities = self.prefs.hiddenEntities

            if hiddenEntities.count == 0 {
                return
            }

            let topMenuItem = NSMenuItem()
            topMenuItem.title = "Hidden Entities"
            topMenuItem.tag = self.menuItemTypeHidden

            let subMenu = NSMenu()

            var menuItems = [NSMenuItem]()
            for entityId in hiddenEntities {
                // Entities that no longer exist in HA are listed by their id so they can still be removed
                let friendlyName = self.haService.haStates.first(where: {$0.entityId == entityId})?.attributes.friendlyName ?? entityId

                let menuItem = NSMenuItem(title: "Show " + friendlyName, action: #selector(self.unhideEntity(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.toolTip = entityId
                menuItem.representedObject = entityId
                menuItems.append(menuItem)
            }

            for menuItem in menuItems.sorted(by: {$0.title < $1.title}) {
                subMenu.addItem(menuItem)
            }

            let position = self.menu.indexOfItem(withTag: self.menuItemPreferences) + 1
            self.menu.insertItem(topMenuItem, at: position)
            self.menu.setSubmenu(subMenu, for: topMenuItem)
        }
    }

    func addErrorMenuItem(message: String) {
        DispatchQueue.main.async {
            // Add a seperator before static menu items
            self.menu.insertItem(NSMenuItem.separator(), at: 0)

            let menuItem = NSMenuItem(title: message, action: #selector(self.openPreferences(sender:)), keyEquivalent: "")
            menuItem.target = self

            menuItem.tag = self.menuItemTypeError // Tag defines what type of item it is
            menuItem.image = NSImage(named: "ErrorImage")

            self.menu.insertItem(menuItem, at: 0)
        }
    }

    func removeDynamicMenuItems() {
        var dynamicItem: NSMenuItem?

        // Entities
        for type in EntityTypes.allCases {
            repeat {
                dynamicItem = self.menu.item(withTag: type.rawValue)
                if (dynamicItem != nil) {
                    self.menu.removeItem(dynamicItem!)
                }
            } while dynamicItem != nil
        }

        // Top Level Menu
        repeat {
            dynamicItem = self.menu.item(withTag: self.menuItemTypeTopLevel)
            if (dynamicItem != nil) {
                self.menu.removeItem(dynamicItem!)
            }
        } while dynamicItem != nil

        // Info
        repeat {
            dynamicItem = self.menu.item(withTag: self.menuItemTypeInfo)
            if (dynamicItem != nil) {
                self.menu.removeItem(dynamicItem!)
            }
        } while dynamicItem != nil

        // Hidden Entities
        repeat {
            dynamicItem = self.menu.item(withTag: self.menuItemTypeHidden)
            if (dynamicItem != nil) {
                self.menu.removeItem(dynamicItem!)
            }
        } while dynamicItem != nil

        // Errors
        repeat {
            dynamicItem = self.menu.item(withTag: self.menuItemTypeError)
            if (dynamicItem != nil) {
                self.menu.removeItem(dynamicItem!)
            }
        } while dynamicItem != nil

        // Remove the top seperators
        while self.menu.item(at: 0) == NSMenuItem.separator() {
            self.menu.removeItem(at: 0)
        }
    }

    @objc func doNothing(_ sender: NSMenuItem) {
        // fake menu responder
    }
    
    @objc func toggleEntityState(_ sender: NSMenuItem) {
        let haEntity: HaEntity = sender.representedObject as! HaEntity
        haService.toggleEntityState(haEntity: haEntity)
    }

    @objc func selectInputSelectOption(_ sender: NSMenuItem) {
        let haEntity: HaEntity = sender.representedObject as! HaEntity
        haService.selectInputSelectOption(haEntity: haEntity, option: sender.title)
    }

    @objc func turnOnEntity(_ sender: NSMenuItem) {
        let haEntity: HaEntity = sender.representedObject as! HaEntity
        haService.turnOnEntity(haEntity: haEntity)
    }
    
    @objc func pressEntity(_ sender: NSMenuItem) {
        let haEntity: HaEntity = sender.representedObject as! HaEntity
        haService.pressEntity(haEntity: haEntity)
    }
    
    @objc func hideEntity(_ sender: NSMenuItem) {
        let haEntity: HaEntity = sender.representedObject as! HaEntity
        var hiddenEntities = prefs.hiddenEntities

        if !hiddenEntities.contains(haEntity.entityId) {
            hiddenEntities.append(haEntity.entityId)
            prefs.hiddenEntities = hiddenEntities
        }
    }

    @objc func unhideEntity(_ sender: NSMenuItem) {
        let entityId = sender.representedObject as! String
        prefs.hiddenEntities = prefs.hiddenEntities.filter({$0 != entityId})
    }

    // Compares versions numerically (3.0.10 is newer than 3.0.9), a leading "v" in the tag is ignored.
    // Only newer releases are offered, so a local build ahead of the latest release is not asked to downgrade.
    func isVersion(_ version: String, newerThan currentVersion: String) -> Bool {
        let cleanVersion = version.hasPrefix("v") ? String(version.dropFirst()) : version
        return cleanVersion.compare(currentVersion, options: .numeric) == .orderedDescending
    }

    func checkForUpdate() {
        let parser = FeedParser(URL: releasesFeedURL)

        parser.parseAsync { [weak self] (result) in
            guard let self = self else { return }
            switch result {
            case .success(let feed):

                // The feed's entry ids end with the release tag. Beta releases are never offered,
                // the newest release that is not a beta counts.
                let tags = (feed.atomFeed?.entries ?? []).compactMap { $0.id?.components(separatedBy: "/").last }

                if let latestVersion = tags.first(where: { !$0.hasSuffix("beta") }) {

                    // Do nothing with final builds, they are pulled manually when required
                    if latestVersion.hasSuffix("final") {
                        return
                    }

                    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String

                    if self.isVersion(latestVersion, newerThan: appVersion) {
                        DispatchQueue.main.async {
                            let menuItem = NSMenuItem(title: "A new version is available", action: #selector(self.openAppWebsite(sender:)), keyEquivalent: "")
                            menuItem.target = self

                            menuItem.tag = self.menuItemTypeInfo // Tag defines what type of item it is
                            menuItem.image = NSImage(named: "InfoImage")

                            let position = self.menu.indexOfItem(withTag: self.menuItemAbout) + 1

                            self.menu.insertItem(menuItem, at: position)
                        }
                    }
                }
                else {
                    print("Unable to get release feed")
                }

            case .failure(let error):
                // Silently ignore
                print(error)
            }
        }
    }
}
