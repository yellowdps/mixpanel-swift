//
//  Persistence.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/2/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

struct ArchivedProperties {
    let superProperties: Properties
    let timedEvents: Properties
    let distinctId: String?
    let peopleDistinctId: String?
    let peopleUnidentifiedQueue: Queue
}

class Persistence {

    enum ArchiveType: String {
        case Events
        case People
        case Properties
    }

    private var apiToken: String = ""

    init(apiToken: String) {
        self.apiToken = apiToken
    }
    
    func filePathWithType(_ type: ArchiveType) -> String? {
        return filePathFor(type.rawValue)
    }

    private func filePathFor(_ data: String) -> String? {
        let filename = "mixpanel-\(apiToken)-\(data)"
        let manager = FileManager.default()
        let url = manager.urlsForDirectory(.libraryDirectory, inDomains: .userDomainMask).last

        guard let urlUnwrapped = try? url?.appendingPathComponent(filename).path else {
            return nil
        }

        return urlUnwrapped
    }

    func archive(_ eventsQueue: Queue, peopleQueue: Queue, properties: ArchivedProperties) {
        archiveEvents(eventsQueue)
        archivePeople(peopleQueue)
        archiveProperties(properties)
    }

    func archiveEvents(_ eventsQueue: Queue) {
        archiveToFile(.Events, object: eventsQueue)
    }

    func archivePeople(_ peopleQueue: Queue) {
        archiveToFile(.People, object: peopleQueue)
    }

    func archiveProperties(_ properties: ArchivedProperties) {
        var p: Properties = Properties()
        p["distinctId"] = properties.distinctId
        p["superProperties"] = properties.superProperties
        p["peopleDistinctId"] = properties.peopleDistinctId
        p["peopleUnidentifiedQueue"] = properties.peopleUnidentifiedQueue
        p["timedEvents"] = properties.timedEvents
        archiveToFile(.Properties, object: p)
    }

    private func archiveToFile(_ type: ArchiveType, object: AnyObject) {
        let filePath = filePathWithType(type)
        guard let path = filePath else {
            print("bad file path, cant fetch file")
            return
        }

        if !NSKeyedArchiver.archiveRootObject(object, toFile: path) {
            print("failed to archive \(type.rawValue)")
        }

    }

    func unarchive() -> (eventsQueue: Queue,
        peopleQueue: Queue,
        superProperties: Properties,
        timedEvents: Properties,
        distinctId: String?,
        peopleDistinctId: String?,
        peopleUnidentifiedQueue: Queue) {
        let eventsQueue = unarchiveEvents()
        let peopleQueue = unarchivePeople()
            
        let (superProperties,
            timedEvents,
            distinctId,
            peopleDistinctId,
            peopleUnidentifiedQueue) = unarchiveProperties()

        return (eventsQueue,
                peopleQueue,
                superProperties,
                timedEvents,
                distinctId,
                peopleDistinctId,
                peopleUnidentifiedQueue)
    }
    
    private func unarchiveWithFilePath(_ filePath: String) -> AnyObject? {
        let unarchivedData: AnyObject? = NSKeyedUnarchiver.unarchiveObject(withFile: filePath)
        if unarchivedData == nil {
            do {
                try FileManager.default().removeItem(atPath: filePath)
            } catch {
                print("unable to remove file")
            }
        }

        return unarchivedData
    }

    private func unarchiveEvents() -> Queue {
        return unarchiveWithType(.Events) as? Queue ?? []
    }

    private func unarchivePeople() -> Queue {
        return unarchiveWithType(.People) as? Queue ?? []
    }

    private func unarchiveProperties() -> (Properties, Properties, String?, String?, Queue) {
        let properties = unarchiveWithType(.Properties) as? Properties
        let superProperties =
            properties?["superProperties"] as? Properties ?? Properties()
        let timedEvents =
            properties?["timedEvents"] as? Properties ?? Properties()
        let distinctId =
            properties?["distinctId"] as? String ?? nil
        let peopleDistinctId =
            properties?["peopleDistinctId"] as? String ?? nil
        let peopleUnidentifiedQueue =
            properties?["peopleUnidentifiedQueue"] as? Queue ?? Queue()

        return (superProperties,
                timedEvents,
                distinctId,
                peopleDistinctId,
                peopleUnidentifiedQueue)
    }

    private func unarchiveWithType(_ type: ArchiveType) -> AnyObject? {
        let filePath = filePathWithType(type)
        guard let path = filePath else {
            print("bad file path, cant fetch file")
            return nil
        }

        guard let unarchivedData = unarchiveWithFilePath(path) else {
            print("can't unarchive file")
            return nil
        }

        return unarchivedData
    }
    
}
