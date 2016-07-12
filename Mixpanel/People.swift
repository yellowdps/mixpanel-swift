//
//  People.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/5/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

public class People {

    public var ignoreTime = false

    let apiToken: String
    let serialQueue: DispatchQueue
    var peopleQueue = Queue()
    var unidentifiedQueue = Queue()
    var distinctId: String? = nil

    init(apiToken: String, serialQueue: DispatchQueue) {
        self.apiToken = apiToken
        self.serialQueue = serialQueue
    }

    func addPeopleRecordToQueueWithAction(_ action: String, properties: Properties) {
        let epochMilliseconds = round(Date().timeIntervalSince1970 * 1000)
        let ignoreTimeCopy = ignoreTime

        serialQueue.async() {
            var r = Properties()
            var p = Properties()
            r["$token"] = self.apiToken
            r["$time"] = epochMilliseconds
            if ignoreTimeCopy {
                r["$ignore_time"] = ignoreTimeCopy
            }
            if action == "$unset" {
                // $unset takes an array of property names which is supplied to this method
                // in the properties parameter under the key "$properties"
                r[action] = properties["$properties"]
            } else {
                if action == "$set" || action == "$set_once" {
                    p += AutomaticProperties.peopleProperties
                }
                p += properties
                r[action] = p
            }

            if let distinctId = self.distinctId {
                r["$distinct_id"] = distinctId
                self.addPeopleObject(r)
            } else {
                self.unidentifiedQueue.append(r)
                if self.unidentifiedQueue.count > QueueConstants.queueSize {
                    self.unidentifiedQueue.remove(at: 0)
                }
            }
            Persistence.archivePeople(self.peopleQueue, token: self.apiToken)
        }
    }
    
    func addPeopleObject(_ r: Properties) {
        peopleQueue.append(r)
        if peopleQueue.count > QueueConstants.queueSize {
            peopleQueue.remove(at: 0)
        }
    }


    // MARK: - People Public API
    public func addPushDeviceToken(_ deviceToken: Data) {
        let tokenChars = UnsafePointer<CChar>((deviceToken as NSData).bytes)
        var tokenString = ""

        for i in 0..<deviceToken.count {
            tokenString += String(format: "%02.2hhx", arguments: [tokenChars[i]])
        }
        let tokens = [tokenString]
        let properties = ["$ios_devices": tokens]
        addPeopleRecordToQueueWithAction("$union", properties: properties)
    }

    public func set(properties: Properties?) {
        MPAssert(properties != nil, "properties must not be nil")
        Track.assertPropertyTypes(properties)
        guard let properties = properties else {
            return
        }
        addPeopleRecordToQueueWithAction("$set", properties: properties)
    }

    public func set(property: String?, to: AnyObject?) {
        MPAssert(property != nil, "property must not be nil")
        MPAssert(to != nil, "to must not be nil")
        guard let property = property, to = to else {
            return
        }
        set(properties: [property: to])
    }

    public func setOnce(properties: Properties?) {
        MPAssert(properties != nil, "properties must not be nil")
        Track.assertPropertyTypes(properties)
        guard let properties = properties else {
            return
        }
        addPeopleRecordToQueueWithAction("$set_once", properties: properties)
    }

    public func unset(properties: [String]?) {
        MPAssert(properties != nil, "properties must not be nil")
        guard let properties = properties else {
            return
        }
        addPeopleRecordToQueueWithAction("$unset", properties: ["$properties":properties])
    }

    public func increment(properties: Properties?) {
        MPAssert(properties != nil, "properties must not be nil")
        guard let properties = properties else {
            return
        }
        let filtered = properties.values.filter() {
            !($0 is Int || $0 is UInt || $0 is Double || $0 is Float) }
        if filtered.count > 0 {
            MPAssert(false, "increment property values should be numbers")
            return
        }
        addPeopleRecordToQueueWithAction("$add", properties: properties)
    }

    public func increment(property: String?, by: Int?) {
        MPAssert(property != nil, "property must not be nil")
        MPAssert(by != nil, "amount must not be nil")
        guard let property = property, by = by else {
            return
        }
        increment(properties: [property: by])
    }

    public func append(properties: Properties?) {
        MPAssert(properties != nil, "properties must not be nil")
        Track.assertPropertyTypes(properties)
        guard let properties = properties else {
            return
        }
        addPeopleRecordToQueueWithAction("$append", properties: properties)
    }

    public func union(properties: Properties?) {
        MPAssert(properties != nil, "properties must not be nil")
        guard let properties = properties else {
            return
        }
        let filtered = properties.values.filter() {
            !($0 is [Any]) }
        if filtered.count > 0 {
            MPAssert(true, "union property values should be an array")
            return
        }
        addPeopleRecordToQueueWithAction("$union", properties: properties)
    }

    public func merge(properties: Properties?) {
        MPAssert(properties != nil, "properties must not be nil")
        guard let properties = properties else {
            return
        }
        addPeopleRecordToQueueWithAction("$merge", properties: properties)
    }

    public func trackCharge(amount: Double?, properties: Properties? = nil) {
        MPAssert(amount != nil, "amount must not be nil")
        guard let amount = amount else {
            return
        }
        var transaction: Properties = ["$amount": amount, "$time": Date()]
        if let properties = properties {
            transaction += properties
        }
        append(properties: ["$transactions": transaction])
    }

    public func clearCharges() {
        set(properties: ["$transactions": []])
    }

    public func deleteUser() {
        addPeopleRecordToQueueWithAction("$delete", properties: [:])
    }
}
