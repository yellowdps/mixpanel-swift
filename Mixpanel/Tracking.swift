//
//  Tracking.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/3/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

func += <K, V> (left: inout [K:V], right: [K:V]) {
    for (k, v) in right {
        left.updateValue(v, forKey: k)
    }
}

class Tracking {
    let apiToken: String

    init(apiToken: String) {
        self.apiToken = apiToken
    }

    class func assertPropertyTypes(_ properties: [String: AnyObject]?) {
        if let properties = properties {
            for (_, v) in properties {
                MPAssert(
                    v is String ||
                    v is Int ||
                    v is UInt ||
                    v is Double ||
                    v is [AnyObject] ||
                    v is [String: AnyObject] ||
                    v is Date ||
                    v is URL ||
                    v is NSNull,
                "Property values must be of valid type. Got \(v.dynamicType)")
            }
        }
    }

    func track(_ event: String?,
               properties: [String:AnyObject]? = nil,
               eventsQueue: inout Queue,
               timedEvents: inout Properties,
               automaticProperties: Properties,
               superProperties: Properties,
               distinctId: String?) {
        var ev = event
        if ev == nil || ev!.characters.count == 0 {
            print("mixpanel track called with empty event parameter. using 'mp_event'")
            ev = "mp_event"
        }

        Tracking.assertPropertyTypes(properties)
        let epochInterval = Date().timeIntervalSince1970
        let epochSeconds = Int(round(epochInterval))
        let eventStartTime = timedEvents[ev!] as? Int
        var p = [String : AnyObject]()
        p += automaticProperties
        p["token"] = self.apiToken
        p["time"] = epochSeconds
        if let eventStartTime = eventStartTime {
            timedEvents.removeValue(forKey: ev!)
            p["$duration"] = CFloat(String(format: "%.3f", epochInterval - Double(eventStartTime)))
        }
        if let distinctId = distinctId {
            p["distinct_id"] = distinctId
        }
        p += superProperties
        if let properties = properties {
            p += properties
        }

        let trackEvent: [String: AnyObject] = ["event": ev!, "properties": p]
        eventsQueue.append(trackEvent)

        if eventsQueue.count > 5000 {
            eventsQueue.remove(at: 0)
        }
    }

    func registerSuperProperties(_ properties: Properties, superProperties: inout Properties) {
        Tracking.assertPropertyTypes(properties)
        superProperties += properties
    }

    func registerSuperPropertiesOnce(_ properties: [String : AnyObject],
                                     superProperties: inout Properties,
                                     defaultValue: AnyObject?) {
        Tracking.assertPropertyTypes(properties)
            _ = properties.map() {
                let val = superProperties[$0.0]
                if val == nil ||
                    (defaultValue != nil && (val as? NSObject == defaultValue as? NSObject)) {
                    superProperties[$0.0] = $0.1
                }
            }
    }

    func unregisterSuperProperty(_ propertyName: String, superProperties: inout Properties) {
        superProperties.removeValue(forKey: propertyName)
    }

    func clearSuperProperties(_ superProperties: inout Properties) {
        superProperties.removeAll()
    }

    func timeEvent(_ event: String?, timedEvents: inout Properties) {
        let startTime = Date().timeIntervalSince1970
        guard let event = event where event.characters.count > 0 else {
            print("mixpanel cannot time an empty event")
            return
        }
        timedEvents[event] = startTime
    }

    func clearTimedEvents(_ timedEvents: inout Properties) {
        timedEvents.removeAll()
    }
}
