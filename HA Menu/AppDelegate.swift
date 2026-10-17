//
//  AppDelegate.swift
//  HA Menu X
//
//  Created by Andrew Jackson on 21/10/2018.
//  Copyright © 2018 CodeChimp. All rights reserved.
//

import Cocoa
import ServiceManagement

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var menuItemController: MenuItemController?
    var prefs = Preferences()


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupPrefs()

        // Unit tests run inside the app with the user's real settings, keep their login item alone
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            migrateLoginItem()
            updateLoginItemLocation()
        }

        menuItemController = MenuItemController()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

extension AppDelegate {
    // MARK: - Preferences
    func setupPrefs() {

        UserDefaults.standard.register(defaults: [
               "domain_lights": true,
               "domain_switches": true,
               "domain_automations": true,
               "domain_inputbooleans": true,
               "domain_inputselects": true,
               "domain_scenes": true,
               "domain_scripts": true,
               "domain_covers": true,
               "domain_buttons": true,
               "domain_inputbuttons": true
               ])
    }

    // Up to version 2 start at login used a helper app and stored the setting in "launch".
    // Since 3.0 the app registers itself as login item, move existing users over once.
    func migrateLoginItem() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "launch") != nil else {
            return
        }

        if defaults.bool(forKey: "launch") {
            // Stop an old HA Menu copy that is still around from starting at login as well
            (LegacyLoginItem() as LegacyLoginItemDisabling).disableHelper()
            prefs.launch = true
        }
        defaults.removeObject(forKey: "launch")
    }

    // The login item points to the app that registered it, follow the app when it was moved or replaced by a copy elsewhere
    func updateLoginItemLocation() {
        let service = SMAppService.mainApp
        guard service.status == .enabled, UserDefaults.standard.string(forKey: "login_item_path") != Bundle.main.bundlePath else {
            return
        }

        do {
            try service.unregister()
        }
        catch {
            print("Unable to move login item: \(error.localizedDescription)")
            return
        }
        prefs.launch = true
    }

}

private protocol LegacyLoginItemDisabling {
    func disableHelper()
}

// Called through the protocol so the deprecated API needed for this one time clean up does not warn on every build
private struct LegacyLoginItem: LegacyLoginItemDisabling {
    @available(macOS, deprecated: 13.0)
    func disableHelper() {
        SMLoginItemSetEnabled("org.codechimp.HA-Menu-Launcher" as CFString, false)
    }
}

