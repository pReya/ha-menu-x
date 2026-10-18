# HA Menu X

[![GitHub Release][releases-shield]](https://github.com/pReya/ha-menu-x/releases)
[![Downloads][download-latest-shield]](https://github.com/pReya/ha-menu-x/releases/latest)
[![License][license-shield]](LICENSE)

![Logo](Art/logo.png)

A MacOS Menu Bar app to control common Home Assistant functions.

HA Menu X is a fork of [HA Menu](https://github.com/codechimp-org/ha-menu) by [Andrew Jackson / CodeChimp](https://github.com/andrew-codechimp). All the credit for the original app goes to them, HA Menu X builds on it with the features below.

## What's new in HA Menu X

* **Rooms** – The areas you have set up in Home Assistant can be shown in the menu, each as its own submenu with the lights, switches, covers, scenes etc. in that room. See [Areas (rooms)](#areas-rooms).
* **Sort items** – Drag the entities within any domain, group or area into the order you want instead of the fixed alphabetical/group order. See [Sorting items](#sorting-items).
* **Hide entities** – Hold the Option (⌥) key in the menu to hide single entities, and bring them back from the Hidden Entities submenu. See [Hiding entities](#hiding-entities).
* **Dark mode icons** – The play and sensor icons follow the menu's light/dark appearance.
* **Built for current macOS** – Requires macOS 13 (Ventura) or later and is built with the current macOS SDK. Start at login now uses the system's login items: HA Menu X shows up in System Settings > General > Login Items like any other app, with no separate helper app, and the setting stays in sync when you change it there.

HA Menu X uses the same settings as HA Menu, so when switching your server, token and menu setup are kept.

## Features

* Turning available switches, lights, automations and input_boolean's on and off
* Activating scenes, scripts, buttons and input_buttons
* input_select option menus  
* Opening and Closing Covers
* Viewing sensor values (Sensors have to be specifically added to a group)  
* Showing entities grouped by the areas (rooms) you have set up in HA
* Sorting the entities within each domain, group or area
* Hiding individual entities

HA Menu X supports MacOS 13 (Ventura) and later, on Apple Silicon and Intel Macs.

<img src="Art/menu.png" width="365" alt="HA Menu X menu with rooms as submenus">

## Installation
**Manual**  
Get the latest HA.Menu.X.zip from [Releases](https://github.com/pReya/ha-menu-x/releases)  
Unzip and copy the HA Menu X app to your Applications folder

HA Menu X is not notarized by Apple, so macOS blocks it on first launch. Open it once, then go to System Settings > Privacy & Security and click Open Anyway. Alternatively run  
```xattr -dr com.apple.quarantine "/Applications/HA Menu X.app"```

When switching from HA Menu, quit and remove it before starting HA Menu X. If you had Start at login turned on it is carried over.

## Configuration

For the server connection you can use your local ip:port as per the example, an external facing address you have setup via DuckDNS or similar, or your Nabu Casa URL.  Ensure you prefix with http:// or https:// as appropriate.

To create a token within HA, login to HA and click on your profile.  
Under Long Lived Access Tokens, create a new token, give it a name and copy the token value into HA Menu X preferences.

Press Connect to validate your connection and get your groups and areas.  You can now choose which domains/groups/areas to display within HA Menu X, drag them to reorder and optionally make them a submenu. Double-click one to sort the entities within it.

<img src="Art/preferences.png" width="537" alt="HA Menu X preferences">

### Domains

Within the preference screen you can choose which domains to display.  Domains are a list of all entities within that domain, e.g. Lights will display all lights within HA Menu X.  
If you want to display just a few items from a domain, create a custom group as detailed below.   
Entities within domains are displayed alphabetically.

### Hiding entities

To hide a single entity, open HA Menu X and hold the Option (⌥) key, each entity turns into a Hide item, click it to hide that entity.  
Hidden entities are removed from domains, groups and areas and are listed in the Hidden Entities submenu below Preferences, click one there to show it again.

### Areas (rooms)

The areas you have set up in HA are listed in preferences alongside domains and groups, in the order HA has them. Tick an area to show its entities, by default as a submenu named after the room.  
An entity belongs to an area when it is assigned to it directly or when its device is. Like HA's own area views, hidden entities and config/diagnostic entities are left out, as are sensors (add sensors to a group if you want to see them).  
When an entity's name starts with the area name it is shortened, e.g. "Kitchen Ceiling Light" is shown as "Ceiling Light" within Kitchen.

### Sorting items

Double-click a domain, group or area in preferences (or right-click it and choose Sort Items…) to drag its entities into the order you want them in the menu.  
Entities added to HA later are appended at the end. Reset to A–Z (or Reset to Group Order for groups) restores the default order.

### Groups

If you have a lot of entities within your domains you can have HA Menu X display a specific set by [creating new groups within HA](https://www.home-assistant.io/integrations/group/).  
You can create multiple groups and they will be separated within the drop down menu.

First of all create your group(s) within groups.yaml as per the example.  Note the group entity id is ha_menu in this example.  Validate and Reload Groups within HA (Configuration/Server Controls) to have the group added to HA. If you want multiple groups just repeat the block and rename the entity id/name and change your entity's.

Once you have the group(s) added to HA, within HA Menu X go to Preferences and tick the Groups you want to be displayed.   
Close preferences to save these settings.

Now when you click on HA Menu X again the group's you have setup will be displayed.  Entities within groups are displayed in the order they are added within the group (printer, lego_lights, desk_lamp, notifications, entry_alert, who_cooks, outside_temperature in the example).  

Where sensors are included they will be displayed with a bullet in the menu, and show the friendly name, state/value and unit of measurement. Clicking on a sensor does not perform any action.   

Example groups.yaml
```yaml
ha_menu:
  name: HA Menu X Switches
  entities:
    - switch.printer
    - switch.lego_lights
    - light.desk_lamp
    - input_boolean.notifications
    - automation.entry_alert
    - input_select.who_cooks
    - sensor.outside_temperature
```

[license-shield]: https://img.shields.io/github/license/pReya/ha-menu-x.svg?style=for-the-badge
[releases-shield]: https://img.shields.io/github/release/pReya/ha-menu-x.svg?style=for-the-badge
[download-latest-shield]: https://img.shields.io/github/downloads/pReya/ha-menu-x/latest/total?style=for-the-badge
