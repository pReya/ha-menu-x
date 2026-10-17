//
//  HaService.swift
//  HA Menu
//
//  Created by Andrew Jackson on 26/01/2020.
//  Copyright © 2020 CodeChimp. All rights reserved.
//

import Foundation

class HaService {

    static var shared = HaService()
    private init() {}

    enum HaServiceApiError: LocalizedError {
        case URLMissing
        case InvalidURL
        case Unauthorized
        case NotFound
        case UnknownResponse
        case JSONDecodeError
        case UnknownError(message: String)
    }

    enum HaServiceEntityError: Error {
        case EntityNotFound
    }

    var haStates: [HaState] = []

    // nil when areas have not been loaded or the last load failed
    var haAreas: [HaArea]?
    var areasError: HaServiceApiError?

    var prefs = Preferences()

    func createAuthURLRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)

        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(prefs.token)", forHTTPHeaderField: "Authorization")

        return request
    }

    // Loads all states, and with includeAreas also the areas (rooms) in parallel.
    // A failing area load does not fail the call, it is reported in areasError instead.
    // The completion handler is called on the main queue.
    func getStates(includeAreas: Bool = false, completionHandler: @escaping (Result<Bool, HaServiceApiError>) -> Void)  {

        if (prefs.server.count == 0 ) {
            completionHandler(.failure(.URLMissing))
            return
        }

        guard let url = URL(string: "\(prefs.server)/api/states") else {
            completionHandler(.failure(.InvalidURL))
            return
        }

        let loading = DispatchGroup()
        var statesResult: Result<Bool, HaServiceApiError> = .failure(.UnknownResponse)

        if includeAreas {
            loading.enter()
            getAreas() { result in
                switch result {
                case .success(let areas):
                    self.haAreas = areas
                    self.areasError = nil
                case .failure(let error):
                    self.haAreas = nil
                    self.areasError = error
                }
                loading.leave()
            }
        }

        loading.enter()
        fetchStates(url: url) { result in
            statesResult = result
            loading.leave()
        }

        loading.notify(queue: .main) {
            completionHandler(statesResult)
        }
    }

    private func fetchStates(url: URL, completionHandler: @escaping (Result<Bool, HaServiceApiError>) -> Void) {
        var request = createAuthURLRequest(url: url)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) {data, response, error in

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    switch httpResponse.statusCode {
                    case 401:
                        completionHandler(.failure(.Unauthorized))
                    case 404:
                        completionHandler(.failure(.NotFound))
                    default:
                        completionHandler(.failure(.UnknownResponse))
                    }
                    return
                }
            }

            if let data = data {
                do {
                    let decodedResponse = try JSONDecoder().decode([HaState].self, from: data)
                    self.haStates = decodedResponse

                    completionHandler(.success(true))

                } catch {
                    completionHandler(.failure(.JSONDecodeError))
                }
                return
            }
            completionHandler(.failure(.UnknownError(message: error?.localizedDescription ?? "")))

        }.resume()
    }

    func getState(entityId: String, completionHandler: @escaping (Result<HaState, HaServiceEntityError>) -> Void) {

        guard let entity = haStates.first(where: {$0.entityId == entityId}) else {
            completionHandler(.failure(.EntityNotFound))
            return
        }

        completionHandler(.success(entity))
    }

    func filterEntities(entityDomain: String) -> [HaEntity] {
        var entities = [HaEntity]()
        let hiddenEntities = prefs.hiddenEntities

        for haState in haStates {
            if (haState.entityId.starts(with: entityDomain + ".")) {
                // Do not add unavailable state entities or ones the user has hidden
                if (haState.state != "unavailable" && !hiddenEntities.contains(haState.entityId)) {

                    let haEntity: HaEntity = HaEntity(entityId: haState.entityId, friendlyName: (haState.attributes.friendlyName), state: (haState.state), unitOfMeasurement: haState.attributes.unitOfMeasurement, options: haState.attributes.options)

                    entities.append(haEntity)
                }
            }
        }

        entities = entities.sorted(by: {$0.friendlyName > $1.friendlyName})

        return entities
    }

    // Entities shown for a menu item (domain, group or area), in the user's custom order if one is set
    func entities(for menuItem: PrefMenuItem) -> [HaEntity] {
        return applyCustomOrder(entities: defaultEntities(for: menuItem), key: menuItem.orderKey)
    }

    // Entities shown for a menu item in their default order:
    // domains and areas alphabetically, groups in the order they are defined in HA
    func defaultEntities(for menuItem: PrefMenuItem) -> [HaEntity] {
        switch menuItem.itemType {
        case itemTypes.Domain:
            return filterEntities(entityDomain: menuItem.entityId).reversed()

        case itemTypes.Group:
            guard let group = haStates.first(where: {$0.entityId == "group.\(menuItem.entityId)"}) else {
                return []
            }
            return group.attributes.entityIds.compactMap { makeEntity(entityId: $0, allowedTypes: groupEntityTypes) }

        case itemTypes.Area:
            guard let area = haAreas?.first(where: {$0.id == menuItem.entityId}) else {
                return []
            }
            var entities = area.entityIds.compactMap { makeEntity(entityId: $0, allowedTypes: areaEntityTypes) }

            // "Kitchen Ceiling Light" reads as "Ceiling Light" within the Kitchen menu
            for index in entities.indices {
                entities[index].friendlyName = stripPrefix(entities[index].friendlyName, prefix: area.name)
            }

            return entities.sorted(by: {$0.friendlyName.localizedStandardCompare($1.friendlyName) == .orderedAscending})
        }
    }

    // Entities listed in the saved order come first, anything new is appended in the default order
    func applyCustomOrder(entities: [HaEntity], key: String) -> [HaEntity] {
        let order = prefs.entityOrder(for: key)
        if order.isEmpty {
            return entities
        }

        var rank = [String: Int]()
        for (index, entityId) in order.enumerated() where rank[entityId] == nil {
            rank[entityId] = index
        }

        return entities.enumerated().sorted { a, b in
            let rankA = rank[a.element.entityId] ?? Int.max
            let rankB = rank[b.element.entityId] ?? Int.max
            return rankA != rankB ? rankA < rankB : a.offset < b.offset
        }.map { $0.element }
    }

    // Domains that can be shown when an entity is a member of a group or area
    private let areaEntityTypes: Set<EntityTypes> = [.switchType, .lightType, .inputBooleanType, .inputSelectType, .automationType, .sceneType, .scriptType, .coverType, .buttonType, .inputButtonType]
    private lazy var groupEntityTypes: Set<EntityTypes> = areaEntityTypes.union([.sensorType])

    // Builds the entity if it is of an allowed type, available and not hidden by the user
    private func makeEntity(entityId: String, allowedTypes: Set<EntityTypes>) -> HaEntity? {
        guard let state = haStates.first(where: {$0.entityId == entityId}) else {
            return nil
        }

        let haEntity = HaEntity(entityId: entityId, friendlyName: state.attributes.friendlyName, state: state.state, unitOfMeasurement: state.attributes.unitOfMeasurement, options: state.attributes.options)

        if !allowedTypes.contains(haEntity.type) || state.state == "unavailable" || prefs.hiddenEntities.contains(entityId) {
            return nil
        }

        return haEntity
    }

    private func stripPrefix(_ name: String, prefix: String) -> String {
        guard !prefix.isEmpty, name.lowercased().hasPrefix(prefix.lowercased() + " ") else {
            return name
        }
        let stripped = name.dropFirst(prefix.count + 1).trimmingCharacters(in: .whitespaces)
        return stripped.isEmpty ? name : stripped
    }

    // Loads areas with their entities over the WebSocket API. Unlike the template API this does not require an admin user.
    func getAreas(completionHandler: @escaping (Result<[HaArea], HaServiceApiError>) -> Void) {
        guard var components = URLComponents(string: prefs.server), let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            completionHandler(.failure(.InvalidURL))
            return
        }
        components.scheme = (scheme == "https" ? "wss" : "ws")
        components.path += "/api/websocket"

        guard let url = components.url else {
            completionHandler(.failure(.InvalidURL))
            return
        }

        HaAreaLoader(url: url, token: prefs.token, completionHandler: completionHandler).start()
    }

    func toggleEntityState(haEntity: HaEntity) {
        let params = ["entity_id": haEntity.entityId]
        let urlString = "\(prefs.server)/api/services/\(haEntity.domain)/toggle"

        var request = createAuthURLRequest(url: URL(string: urlString)!)

        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])

        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error -> Void in
            print(String(data: data!, encoding: String.Encoding.utf8)!)
        })

        task.resume()
    }

    func selectInputSelectOption(haEntity: HaEntity, option: String) {
        let params = ["entity_id": haEntity.entityId, "option": option]

        var request = createAuthURLRequest(url: URL(string: "\(prefs.server)/api/services/input_select/select_option")!)

        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])

        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error -> Void in
            print(String(data: data!, encoding: String.Encoding.utf8)!)
        })

        task.resume()
    }

    func turnOnEntity(haEntity: HaEntity) {
        let params = ["entity_id": haEntity.entityId]
        let urlString = "\(prefs.server)/api/services/\(haEntity.domain)/turn_on"

        var request = createAuthURLRequest(url: URL(string: urlString)!)

        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])

        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error -> Void in
            print(String(data: data!, encoding: String.Encoding.utf8)!)
        })

        task.resume()
    }
    
    func pressEntity(haEntity: HaEntity) {
        let params = ["entity_id": haEntity.entityId]
        let urlString = "\(prefs.server)/api/services/\(haEntity.domain)/press"

        var request = createAuthURLRequest(url: URL(string: urlString)!)

        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])

        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error -> Void in
            print(String(data: data!, encoding: String.Encoding.utf8)!)
        })

        task.resume()
    }

    
}

struct HaArea {
    var id: String
    var name: String
    var entityIds: [String]
}

// Short lived WebSocket connection that reads the area, device and entity registries
// and resolves which entities belong to which area (an entity inherits its device's area).
// Entities that are hidden or have an entity category (config/diagnostic) are left out, as HA does on its area dashboards.
private final class HaAreaLoader {
    private enum Command: Int, CaseIterable {
        case areas = 1
        case devices = 2
        case entities = 3

        var type: String {
            switch self {
            case .areas: return "config/area_registry/list"
            case .devices: return "config/device_registry/list"
            case .entities: return "config/entity_registry/list_for_display"
            }
        }
    }

    private let task: URLSessionWebSocketTask
    private let token: String
    private let queue = DispatchQueue(label: "org.codechimp.hamenu.areas")
    private var completionHandler: ((Result<[HaArea], HaService.HaServiceApiError>) -> Void)?
    private var results = [Command: Any]()

    init(url: URL, token: String, completionHandler: @escaping (Result<[HaArea], HaService.HaServiceApiError>) -> Void) {
        self.task = URLSession.shared.webSocketTask(with: url)
        // Registries of larger installations easily exceed the 1MB default
        self.task.maximumMessageSize = 64 * 1024 * 1024
        self.token = token
        self.completionHandler = completionHandler
    }

    // The loader keeps itself alive through its pending callbacks until it finishes
    func start() {
        task.resume()
        receive()

        queue.asyncAfter(deadline: .now() + 15) {
            self.finish(.failure(.UnknownError(message: "Timed out loading areas")))
        }
    }

    private func receive() {
        task.receive { result in
            self.queue.async {
                guard self.completionHandler != nil else { return }

                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handle(data: Data(text.utf8))
                    case .data(let data):
                        self.handle(data: data)
                    @unknown default:
                        break
                    }
                    self.receive()
                case .failure(let error):
                    self.finish(.failure(.UnknownError(message: error.localizedDescription)))
                }
            }
        }
    }

    private func handle(data: Data) {
        guard let message = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let type = message["type"] as? String else {
            finish(.failure(.JSONDecodeError))
            return
        }

        switch type {
        case "auth_required":
            send(["type": "auth", "access_token": token])
        case "auth_ok":
            for command in Command.allCases {
                send(["id": command.rawValue, "type": command.type])
            }
        case "auth_invalid":
            finish(.failure(.Unauthorized))
        case "result":
            guard let id = message["id"] as? Int, let command = Command(rawValue: id) else {
                return
            }
            guard message["success"] as? Bool == true, let result = message["result"] else {
                let error = (message["error"] as? [String: Any])?["message"] as? String ?? "Unknown error"
                finish(.failure(.UnknownError(message: error)))
                return
            }
            results[command] = result
            if results.count == Command.allCases.count {
                finish(.success(buildAreas()))
            }
        default:
            break
        }
    }

    private func send(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload), let text = String(data: data, encoding: .utf8) else {
            return
        }
        task.send(.string(text)) { error in
            if let error = error {
                self.queue.async {
                    self.finish(.failure(.UnknownError(message: error.localizedDescription)))
                }
            }
        }
    }

    private func buildAreas() -> [HaArea] {
        let areaList = results[.areas] as? [[String: Any]] ?? []
        let deviceList = results[.devices] as? [[String: Any]] ?? []
        let entityList = (results[.entities] as? [String: Any])?["entities"] as? [[String: Any]] ?? []

        var deviceAreas = [String: String]()
        for device in deviceList {
            if let deviceId = device["id"] as? String, let areaId = device["area_id"] as? String {
                deviceAreas[deviceId] = areaId
            }
        }

        var areaEntities = [String: [String]]()
        for entity in entityList {
            // "ec" = entity category, "hb" = hidden
            guard let entityId = entity["ei"] as? String, entity["ec"] == nil, entity["hb"] == nil else {
                continue
            }
            let areaId = entity["ai"] as? String ?? (entity["di"] as? String).flatMap { deviceAreas[$0] }
            if let areaId = areaId {
                areaEntities[areaId, default: []].append(entityId)
            }
        }

        // Keep the order of the area registry
        return areaList.compactMap { area in
            guard let id = area["area_id"] as? String else { return nil }
            let name = area["name"] as? String ?? id
            return HaArea(id: id, name: name, entityIds: areaEntities[id] ?? [])
        }
    }

    private func finish(_ result: Result<[HaArea], HaService.HaServiceApiError>) {
        guard let completionHandler = completionHandler else { return }
        self.completionHandler = nil
        task.cancel(with: .normalClosure, reason: nil)
        completionHandler(result)
    }
}
