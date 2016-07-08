//
//  People.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/5/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

protocol PeopleDelegate {
    func archivePeople()
    func addPeopleObject(_ r: Properties)
}

public class People {

    public var ignoreTime: Bool? = nil

    let apiToken: String
    let serialQueue: DispatchQueue
    var unidentifiedQueue: Queue
    var automaticPeopleProperties: Properties!
    var distinctId: String? = nil
    var delegate: PeopleDelegate?

    init(apiToken: String, serialQueue: DispatchQueue) {
        self.apiToken = apiToken
        self.serialQueue = serialQueue
        unidentifiedQueue = []
        automaticPeopleProperties = collectAutomaticPeopleProperties()
    }

    func collectAutomaticPeopleProperties() -> Properties {
        var p = Properties()
        let infoDict = Bundle.main().infoDictionary
        if let infoDict = infoDict {
            p["$ios_app_version"] = infoDict["CFBundleVersion"]
            p["$ios_app_release"] = infoDict["CFBundleShortVersionString"]
        }
        p["$ios_device_model"]  = MixpanelInstance.deviceModel()
        p["$ios_ifa"]           = MixpanelInstance.IFA()
        p["$ios_version"]       = UIDevice.current().systemVersion
        p["$ios_lib_version"]   = MixpanelInstance.libVersion()

        return p
    }

    func addPeopleRecordToQueueWithAction(_ action: String, properties: Properties) {
        let epochMilliseconds = round(Date().timeIntervalSince1970 * 1000)
        let ignoreTimeCopy = ignoreTime

        serialQueue.async(execute: {
            var r = Properties()
            var p = Properties()
            r["$token"] = self.apiToken
            r["$time"] = epochMilliseconds
            if let ignoreTimeCopy = ignoreTimeCopy {
                r["$ignore_time"] = ignoreTimeCopy
            }
            if action == "$unset" {
                // $unset takes an array of property names which is supplied to this method
                // in the properties parameter under the key "$properties"
                r[action] = properties["$properties"]
            } else {
                if action == "$set" || action == "$set_once" {
                    p += self.automaticPeopleProperties
                }
                p += properties
                r[action] = p
            }

            if let distinctId = self.distinctId {
                r["$distinct_id"] = distinctId
                self.delegate?.addPeopleObject(r)
            } else {
                self.unidentifiedQueue.append(r)
                if self.unidentifiedQueue.count > 500 {
                    self.unidentifiedQueue.remove(at: 0)
                }
            }
            self.delegate?.archivePeople()
        })

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

    public func removePushDeviceToken() {
        let p = ["$properties": ["$ios_devices"]]
        addPeopleRecordToQueueWithAction("$unset", properties: p)
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
            !($0 is [Any] || $0 is [AnyObject] || $0 is NSArray) }
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
