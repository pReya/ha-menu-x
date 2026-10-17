//
//  PrefsViewController.swift
//  HA Menu X
//
//  Created by Andrew Jackson on 04/11/2018.
//  Copyright © 2018 CodeChimp. All rights reserved.
//

import Cocoa

class PrefsViewController: NSViewController {

    var haService = HaService.shared

    @IBOutlet weak var textfieldServer: NSTextField!
    @IBOutlet weak var textfieldToken: NSTextField!
    @IBOutlet weak var buttonLogin: NSButton!
    @IBOutlet weak var textfieldStatus: NSTextField!
    @IBOutlet weak var tableViewGroups: NSTableView!

    @IBAction func buttonCheckConnection(_ sender: NSButton) {
        connect()
    }

    var prefs = Preferences()
    var groups = [HaEntity]()
    var menuItems = [PrefMenuItem]()
    var okToSaveMenuItems = false
    private var dragDropType = NSPasteboard.PasteboardType(rawValue: "private.table-row")


    override func viewDidLoad() {
        super.viewDidLoad()
        showExistingPrefs()

        tableViewGroups.delegate = self
        tableViewGroups.dataSource = self
        tableViewGroups.registerForDraggedTypes([dragDropType])
        tableViewGroups.target = self
        tableViewGroups.doubleAction = #selector(tableViewGroupsDoubleClick(_:))
        tableViewGroups.toolTip = "Drag to reorder, double-click to sort the items within"

        let contextMenu = NSMenu()
        contextMenu.addItem(NSMenuItem(title: "Sort Items…", action: #selector(sortItemsFromContextMenu(_:)), keyEquivalent: ""))
        tableViewGroups.menu = contextMenu

        connect()
    }

    override func viewWillDisappear() {
        saveNewPrefs()
        saveNewMenuItems()
        NSApp.stopModal()
        super.viewWillDisappear()
    }

    func connect() {
        saveNewPrefs()

        self.menuItems.removeAll()
        
        haService.getStates(includeAreas: true) {
            result in
            switch result {
            case .success( _):
                DispatchQueue.main.async {
                    self.okToSaveMenuItems = true
                    if let areasError = self.haService.areasError {
                        self.textfieldStatus.stringValue = "Connected, but unable to load areas (\(self.describe(areasError)))"
                    } else {
                        self.textfieldStatus.stringValue = "Connected"
                    }

                    self.groups = self.haService.filterEntities(entityDomain: EntityDomains.groupDomain.rawValue).reversed()

                    self.menuItems = self.prefs.menuItemsWithFriendlyNames(groups: self.groups, areas: self.haService.haAreas)

                    self.tableViewGroups.reloadData()
                }

            case .failure(let haServiceApiError):
                DispatchQueue.main.async {
                    self.okToSaveMenuItems = false

                    self.menuItems.removeAll()
                    self.tableViewGroups.reloadData()

                    switch haServiceApiError {
                    case .URLMissing:
                        self.textfieldStatus.stringValue = "Server URL missing"
                    case .InvalidURL:
                        self.textfieldStatus.stringValue = "Invalid URL"
                    case .Unauthorized:
                        self.textfieldStatus.stringValue = "Unauthorized"
                    case .NotFound:
                        self.textfieldStatus.stringValue = "Not Found"
                    case .UnknownResponse:
                        self.textfieldStatus.stringValue = "Unknown Response"
                    case .JSONDecodeError:
                        self.textfieldStatus.stringValue = "Error Decoding JSON"
                    case .UnknownError:
                        print(haServiceApiError.localizedDescription)
                        self.textfieldStatus.stringValue = "Unknown Error (check your server/port)"
                    }
                }
            }
        }
    }

    func showExistingPrefs() {
        textfieldServer.stringValue = prefs.server
        textfieldToken.stringValue = prefs.token
        buttonLogin.state = (prefs.launch == true ? .on : .off)
    }

    func saveNewPrefs() {
        prefs.server = textfieldServer.stringValue
        prefs.token = textfieldToken.stringValue
        prefs.launch = (buttonLogin.state == .on)

        NotificationCenter.default.post(name: Notification.Name(rawValue: "PrefsChanged"),
                                        object: nil)
    }

    func saveNewMenuItems() {
        if okToSaveMenuItems {
            prefs.menuItems = menuItems
        }
    }

    func describe(_ error: HaService.HaServiceApiError) -> String {
        switch error {
        case .Unauthorized:
            return "unauthorized"
        case .InvalidURL, .URLMissing:
            return "invalid URL"
        case .UnknownError(let message):
            return message
        default:
            return "unexpected response"
        }
    }

    @objc func tableViewGroupsDoubleClick(_ sender: AnyObject) {
        showEntityOrder(row: tableViewGroups.clickedRow)
    }

    @objc func sortItemsFromContextMenu(_ sender: NSMenuItem) {
        showEntityOrder(row: tableViewGroups.clickedRow)
    }

    func showEntityOrder(row: Int) {
        guard okToSaveMenuItems, row >= 0, row < menuItems.count else {
            return
        }

        let item = menuItems[row]
        let orderViewController = EntityOrderViewController(menuItem: item,
                                                            entities: haService.entities(for: item),
                                                            defaultEntities: haService.defaultEntities(for: item))
        presentAsSheet(orderViewController)
    }

}

extension PrefsViewController: NSTableViewDelegate, NSTableViewDataSource {

    public func numberOfRows(in tableView: NSTableView) -> Int {
        return self.menuItems.count
    }

    //    fileprivate enum TableColumns {
    //        static let GroupName = NSUserInterfaceItemIdentifier("GroupName")
    //    }

    private func tableView(_ tableView: NSTableView, typeSelectStringFor tableColumn: NSTableColumn?, row: Int) -> PrefMenuItem? {
        return self.menuItems[row]
    }

    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?
        , row: Int) -> Any? {

        if tableColumn == tableView.tableColumns[0] {
            let cell = tableColumn!.dataCell as! NSButtonCell
            let item = self.menuItems[row]

            cell.state = (item.enabled ? .on : .off)
            return cell
        }

        if tableColumn == tableView.tableColumns[1] {
            let item = self.menuItems[row]
            return item.friendlyName
        }

        if tableColumn == tableView.tableColumns[2] {
            let cell = tableColumn!.dataCell as! NSButtonCell
            let item = self.menuItems[row]

            cell.state = (item.subMenu ? .on : .off)
            return cell
        }

        return nil
    }


    func tableView(_ tableView: NSTableView, setObjectValue object: Any?
        , for tableColumn: NSTableColumn?, row: Int) {

        if tableColumn == tableView.tableColumns[0] {
            if (object! as AnyObject).intValue == 1 {
                self.menuItems[row].enabled = true
            } else {
                self.menuItems[row].enabled = false
            }
        }

        if tableColumn == tableView.tableColumns[2] {
            if (object! as AnyObject).intValue == 1 {
                self.menuItems[row].subMenu = true
            } else {
                self.menuItems[row].subMenu = false
            }
        }
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {

        let item = NSPasteboardItem()
        item.setString(String(row), forType: self.dragDropType)
        return item
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {

        if dropOperation == .above {
            return .move
        }
        return []
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {

        var oldIndexes = [Int]()
        info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) { dragItem, _, _ in
            if let str = (dragItem.item as! NSPasteboardItem).string(forType: self.dragDropType), let index = Int(str) {
                oldIndexes.append(index)
            }
        }


        let oldIndex = oldIndexes[0]
        let element = menuItems.remove(at: oldIndexes[0])

        if oldIndex < row {
            self.menuItems.insert(element, at: row - 1)
        }
        else {
            self.menuItems.insert(element, at: row)
        }

        tableView.reloadData()
        return true
    }

}

// Sheet to drag the entities of one domain, group or area into a custom order
final class EntityOrderViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    private let menuItem: PrefMenuItem
    private var entities: [HaEntity]
    private let defaultEntities: [HaEntity]
    private let tableView = NSTableView()
    private let dragDropType = NSPasteboard.PasteboardType(rawValue: "private.entity-row")
    private var prefs = Preferences()

    init(menuItem: PrefMenuItem, entities: [HaEntity], defaultEntities: [HaEntity]) {
        self.menuItem = menuItem
        self.entities = entities
        self.defaultEntities = defaultEntities
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 440))

        let title = NSTextField(labelWithString: "Sort \(menuItem.friendlyName)")
        title.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)

        let hint = NSTextField(labelWithString: entities.isEmpty ? "There are no items to sort." : "Drag items into the order they should appear in the menu.")
        hint.textColor = .secondaryLabelColor

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Entity"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerForDraggedTypes([dragDropType])
        tableView.draggingDestinationFeedbackStyle = .gap

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let resetButton = NSButton(title: defaultOrderTitle(), target: self, action: #selector(resetOrder(_:)))
        let doneButton = NSButton(title: "Done", target: self, action: #selector(done(_:)))
        doneButton.keyEquivalent = "\r"

        for subview in [title, hint, scrollView, resetButton, doneButton] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            title.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),

            hint.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            hint.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            hint.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),

            resetButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 16),
            resetButton.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            resetButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),

            doneButton.centerYAnchor.constraint(equalTo: resetButton.centerYAnchor),
            doneButton.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            doneButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
        ])

        view = container
    }

    private func defaultOrderTitle() -> String {
        return menuItem.itemType == itemTypes.Group ? "Reset to Group Order" : "Reset to A–Z"
    }

    @objc func resetOrder(_ sender: NSButton) {
        entities = defaultEntities
        tableView.reloadData()
    }

    @objc func done(_ sender: NSButton) {
        let entityIds = entities.map { $0.entityId }

        // Only keep an order when it differs from the default, so new entities keep falling into place
        if entityIds == defaultEntities.map({ $0.entityId }) {
            prefs.setEntityOrder([], for: menuItem.orderKey)
        } else {
            prefs.setEntityOrder(entityIds, for: menuItem.orderKey)
        }

        dismiss(self)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return entities.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("EntityCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? {
            let cell = NSTableCellView()
            cell.identifier = identifier
            let textField = NSTextField(labelWithString: "")
            textField.lineBreakMode = .byTruncatingTail
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(textField)
            cell.textField = textField
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            return cell
        }()

        let entity = entities[row]
        cell.textField?.stringValue = entity.friendlyName
        cell.toolTip = entity.entityId
        return cell
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: dragDropType)
        return item
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        return dropOperation == .above ? .move : []
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let item = info.draggingPasteboard.pasteboardItems?.first,
              let string = item.string(forType: dragDropType),
              let oldIndex = Int(string), oldIndex < entities.count else {
            return false
        }

        let entity = entities.remove(at: oldIndex)
        entities.insert(entity, at: oldIndex < row ? row - 1 : row)

        tableView.reloadData()
        return true
    }
}
