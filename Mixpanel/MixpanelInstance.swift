//
//  MixpanelInstance.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/2/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import CoreTelephony

public protocol MixpanelDelegate {
    func mixpanelWillFlush(_ mixpanel: MixpanelInstance) -> Bool
}

public typealias Properties = [String:AnyObject]
public typealias Queue = [Properties]

public class MixpanelInstance: FlushDelegate, PeopleDelegate {
    
    public var delegate: MixpanelDelegate?
    public var distinctId: String?
    public var people: People!
    public var showNetworkActivityIndicator: Bool
    public var flushInterval: Double {
        set {
            flushInstance.flushInterval = newValue
        }
        get {
            return flushInstance.flushInterval
        }
    }
    public var flushOnBackground: Bool {
        set {
            flushInstance.flushOnBackground = newValue
        }
        get {
            return flushInstance.flushOnBackground
        }
    }
    public var useIPAddressForGeoLocation: Bool {
        set {
            flushInstance.useIPAddressForGeoLocation = newValue
        }
        get {
            return flushInstance.useIPAddressForGeoLocation
        }
    }
    public var serverURL: String {
        set {
            flushInstance.serverURL = newValue
        }
        get {
            return flushInstance.serverURL
        }
    }
    
    var apiToken: String
    var superProperties: Properties = [:]
    var eventsQueue: Queue = []
    var peopleQueue: Queue = []
    var timedEvents: Properties = [:]
    var serialQueue: DispatchQueue!
    var taskId: UIBackgroundTaskIdentifier
    var automaticProperties: Properties!
    var telephonyInfo: CTTelephonyNetworkInfo
    var persistence: Persistence
    var flushInstance: Flush
    var trackInstance: Track

    init(apiToken: String?, launchOptions: [NSObject: AnyObject]?, flushInterval: Double) {
        if let apiToken = apiToken where apiToken.characters.count > 0 {
            self.apiToken = apiToken
        } else {
            print("warning: empty api token")
            self.apiToken = ""
        }

        showNetworkActivityIndicator = true
        taskId = UIBackgroundTaskInvalid
        telephonyInfo = CTTelephonyNetworkInfo()
        persistence = Persistence(apiToken: self.apiToken)
        trackInstance = Track(apiToken: self.apiToken)
        flushInstance = Flush()
        flushInstance.delegate = self
        let label = "com.mixpanel.\(apiToken).\(self)"
        serialQueue = DispatchQueue(label: label, attributes: DispatchQueueAttributes.serial)
        people = People(apiToken: self.apiToken, serialQueue: serialQueue)
        people.delegate = self
        automaticProperties = collectAutomaticProperties()
        distinctId = defaultDistinctId()
        flushInstance._flushInterval = flushInterval

        setupListeners()
        unarchive()

        if let launchOptionsKey =
            launchOptions?[UIApplicationLaunchOptionsRemoteNotificationKey] as? Properties {
            //track push notification
            trackPushNotification(launchOptionsKey, event:"$app_open")
        }
    }

    private func setupListeners() {
        let notificationCenter = NotificationCenter.default()

        setCurrentRadio()
        notificationCenter.addObserver(self,
                                       selector: #selector(setCurrentRadio),
                                       name: Notification.Name.CTRadioAccessTechnologyDidChange,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationWillTerminate(_:)),
                                       name: Notification.Name.UIApplicationWillTerminate,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationWillResignActive(_:)),
                                       name: Notification.Name.UIApplicationWillResignActive,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationDidBecomeActive(_:)),
                                       name: Notification.Name.UIApplicationDidBecomeActive,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationDidEnterBackground(_:)),
                                       name: Notification.Name.UIApplicationDidEnterBackground,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationWillEnterForeground(_:)),
                                       name: Notification.Name.UIApplicationWillEnterForeground,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(appLinksNotificationRaised(_:)),
                                       name: "com.parse.bolts.measurement_event",
                                       object: nil)
    }

    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        flushInstance.applicationDidBecomeActive()
    }

    @objc private func applicationWillResignActive(_ notification: Notification) {
        flushInstance.applicationWillResignActive()
    }

    func beginBackgroundUpdateTask() -> UIBackgroundTaskIdentifier {
        return UIApplication.shared().beginBackgroundTask(expirationHandler: {
            self.taskId = UIBackgroundTaskInvalid
        })
    }

    func endBackgroundUpdateTask(_ taskID: UIBackgroundTaskIdentifier) {
        UIApplication.shared().endBackgroundTask(taskID)
    }

    @objc private func applicationDidEnterBackground(_ notification: Notification) {
        taskId = beginBackgroundUpdateTask()
        
        if flushOnBackground {
            flush()
        }

        serialQueue.async(execute: {
            self.archive()

            if self.taskId != UIBackgroundTaskInvalid {
                self.endBackgroundUpdateTask(self.taskId)
                self.taskId = UIBackgroundTaskInvalid
            }
        })
    }

    @objc private func applicationWillEnterForeground(_ notification: Notification) {
        serialQueue.async(execute: {
            if self.taskId != UIBackgroundTaskInvalid {
                UIApplication.shared().endBackgroundTask(self.taskId)
                self.taskId = UIBackgroundTaskInvalid
                self.updateNetworkActivityIndicator(false)
            }
        })
    }

    @objc private func applicationWillTerminate(_ notification: Notification) {
        serialQueue.async(execute: {
            self.archive()
        })
    }

    @objc private func appLinksNotificationRaised(_ notification: Notification) {
        let eventMap = ["al_nav_out": "$al_nav_out",
                        "al_nav_in": "$al_nav_in",
                        "al_ref_back_out": "$al_ref_back_out"]
        let userInfo = (notification as NSNotification).userInfo

        if let eventName = userInfo?["event_name"] as? String,
            eventArgs = userInfo?["event_args"] as? Properties,
            eventNameMap = eventMap[eventName] {
            track(event: eventNameMap, properties:eventArgs)
        }
    }

    func collectAutomaticProperties() -> Properties {
        var p = Properties()
        let size = UIScreen.main().bounds.size
        let infoDict = Bundle.main().infoDictionary
        if let infoDict = infoDict {
            p["$app_version"] =         infoDict["CFBundleVersion"]
            p["$app_release"] =         infoDict["CFBundleShortVersionString"]
            p["$app_build_number"] =    infoDict["CFBundleVersion"]
            p["$app_version_string"] =  infoDict["CFBundleShortVersionString"]
        }
        p["$ios_ifa"]           = MixpanelInstance.IFA()
        p["$carrier"]           = telephonyInfo.subscriberCellularProvider?.carrierName
        p["mp_lib"]             = "iphone"
        p["$lib_version"]       = MixpanelInstance.libVersion()
        p["$manufacturer"]      = "Apple"
        p["$os"]                = UIDevice.current().systemName
        p["$os_version"]        = UIDevice.current().systemVersion
        p["$model"]             = MixpanelInstance.deviceModel()
        p["mp_device_model"]    = p["$model"] //legacy
        p["$screen_height"]     = Int(size.height)
        p["$screen_width"]      = Int(size.width)
        return p
    }

    func defaultDistinctId() -> String {
        var distinctId: String? = MixpanelInstance.IFA()

        guard let ifa = distinctId else {
            if NSClassFromString("UIDevice") != nil {
                distinctId = UIDevice.current().identifierForVendor?.uuidString
            }

            if distinctId == nil {
                distinctId = UUID().uuidString
            }

            return distinctId!
        }
        return ifa
    }

    func updateNetworkActivityIndicator(_ on: Bool) {
        if showNetworkActivityIndicator {
            UIApplication.shared().isNetworkActivityIndicatorVisible = on
        }
    }

    func description() -> String {
        return "<Mixpanel: \(self) \(apiToken)>"
    }

    func getCurrentRadio() -> String {
        var radio = telephonyInfo.currentRadioAccessTechnology
        let prefix = "CTRadioAccessTechnology"
        if radio == nil {
            radio = "None"
        } else if radio!.hasPrefix(prefix) {
            radio = (radio! as NSString).substring(from: prefix.characters.count)
        }
        return radio!
    }

    @objc func setCurrentRadio() {
        serialQueue.async(execute: {
            if self.automaticProperties != nil {
                self.automaticProperties["$radio"] = self.getCurrentRadio()
            }
        })
    }

    static func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafeMutablePointer(&systemInfo.machine) {
            ptr in String(cString: UnsafePointer<CChar>(ptr))
        }
        if let model = String(validatingUTF8: modelCode) {
            return model
        }
        return ""
    }

    static func libVersion() -> String? {
        return Bundle.main().infoDictionary?["CFBundleShortVersionString"] as? String
    }

    static func IFA() -> String? {
        //TODO: Need to find workaround to call this dynamically or not use it at all
//        if (ASIdentifierManager.shared().isAdvertisingTrackingEnabled) {
//            return ASIdentifierManager.shared().advertisingIdentifier.uuidString
//        }
        return nil
    }

    static func inBackground() -> Bool {
        return UIApplication.shared().applicationState == UIApplicationState.background
    }
}

// MARK: - Identity
extension MixpanelInstance {

    public func identify(distinctId: String?) {
        guard let distinctId = distinctId where distinctId.characters.count > 0 else {
            print("\(self) cannot identify blank distinct id")
            return
        }

        serialQueue.async(execute: {
            self.distinctId = distinctId
            self.people.distinctId = distinctId
            if self.people.unidentifiedQueue.count > 0 {
                for var r in self.people.unidentifiedQueue {
                    r["$distinct_id"] = distinctId
                    self.peopleQueue.append(r)
                }
                self.people.unidentifiedQueue.removeAll()
                self.persistence.archivePeople(self.peopleQueue)
            }
            if MixpanelInstance.inBackground() {
                self.archiveProperties()
            }
        })
    }

    public func createAlias(_ alias: String?, distinctId: String?) {
        guard let distinctId = distinctId where distinctId.characters.count > 0 else {
            print("\(self) cannot identify blank distinct id")
            return
        }

        guard let alias = alias where alias.characters.count > 0 else {
            print("\(self) create alias called with empty alias")
            return
        }

        track(event: "$create_alias",
              properties: ["distinct_id": distinctId, "alias": alias])
        flush()
    }

    public func reset() {
        serialQueue.async(execute: {
            self.distinctId = self.defaultDistinctId()
            self.superProperties = [:]
            self.eventsQueue = []
            self.peopleQueue = []
            self.timedEvents = [:]
            self.people.distinctId = nil
            self.people.unidentifiedQueue = []
            self.archive()
        })
    }
}

// MARK: - Persistence
extension MixpanelInstance {

    public func archive() {
        let properties = ArchivedProperties(superProperties: superProperties,
                                            timedEvents: timedEvents,
                                            distinctId: distinctId,
                                            peopleDistinctId: people.distinctId,
                                            peopleUnidentifiedQueue: people.unidentifiedQueue)
        persistence.archive(eventsQueue, peopleQueue: peopleQueue, properties: properties)
    }

    func unarchive() {
        (eventsQueue,
         peopleQueue,
         superProperties,
         timedEvents,
         distinctId,
         people.distinctId,
         people.unidentifiedQueue) = persistence.unarchive()

        if distinctId == nil {
            distinctId = defaultDistinctId()
        }
    }

    func archiveProperties() {
        let properties = ArchivedProperties(superProperties: superProperties,
                                            timedEvents: timedEvents,
                                            distinctId: distinctId,
                                            peopleDistinctId: people.distinctId,
                                            peopleUnidentifiedQueue: people.unidentifiedQueue)
        persistence.archiveProperties(properties)
    }
}

// MARK: - Flush
extension MixpanelInstance {

    public func flush(completion: (() -> Void)? = nil) {
        serialQueue.async(execute: {
            if let shouldFlush = self.delegate?.mixpanelWillFlush(self) where !shouldFlush {
                return
            }

            self.flushInstance.flushEventsQueue(&self.eventsQueue)
            self.flushInstance.flushPeopleQueue(&self.peopleQueue)
            self.archive()

            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
        })
    }
}

// MARK: - Track
extension MixpanelInstance {

    public func track(event: String?, properties: Properties? = nil) {
        serialQueue.async(execute: {
            self.trackInstance.track(event: event,
                properties: properties,
                eventsQueue: &self.eventsQueue,
                timedEvents: &self.timedEvents,
                automaticProperties: self.automaticProperties,
                superProperties: self.superProperties,
                distinctId: self.distinctId)
            self.persistence.archiveEvents(self.eventsQueue)
        })
    }

    public func trackPushNotification(_ userInfo: Properties?,
                                      event: String = "$campaign_received") {
        if let mpPayload = userInfo?["mp"] as? [String: AnyObject] {
            if let m = mpPayload["m"], c = mpPayload["c"] {
                self.track(event: event,
                           properties: ["campaign_id": c,
                                        "message_id": m,
                                        "message_type": "push"])
            } else {
                print("malformed mixpanel push payload")
            }
        }
    }

    public func time(event: String?) {
        serialQueue.async(execute: {
            self.trackInstance.time(event: event, timedEvents: &self.timedEvents)
        })
    }

    public func clearTimedEvents() {
        serialQueue.async(execute: {
            self.trackInstance.clearTimedEvents(&self.timedEvents)
        })
    }

    public func currentSuperProperties() -> Properties {
        return superProperties
    }

    public func clearSuperProperties() {
        serialQueue.async(execute: {
            self.trackInstance.clearSuperProperties(&self.superProperties)
            if MixpanelInstance.inBackground() {
                self.archiveProperties()
            }
        })
    }

    public func registerSuperProperties(_ properties: Properties?) {
        serialQueue.async(execute: {
            if let properties = properties {
                self.trackInstance.registerSuperProperties(properties,
                                                      superProperties: &self.superProperties)
                if MixpanelInstance.inBackground() {
                    self.archiveProperties()
                }
            }
        })
    }

    public func registerSuperPropertiesOnce(_ properties: Properties?,
                                            defaultValue: AnyObject? = nil) {
        serialQueue.async(execute: {
            if let properties = properties {
                self.trackInstance.registerSuperPropertiesOnce(properties,
                                                          superProperties: &self.superProperties,
                                                          defaultValue: defaultValue)
                if MixpanelInstance.inBackground() {
                    self.archiveProperties()
                }
            }
        })
    }

    public func unregisterSuperProperty(_ propertyName: String) {
        serialQueue.async(execute: {
            self.trackInstance.unregisterSuperProperty(propertyName,
                                                  superProperties: &self.superProperties)
            if MixpanelInstance.inBackground() {
                self.archiveProperties()
            }
        })
    }
}

// MARK: - People
extension MixpanelInstance {
    func archivePeople() {
        persistence.archivePeople(self.peopleQueue)
    }

    func addPeopleObject(_ r: Properties) {
        peopleQueue.append(r)
        if peopleQueue.count > 500 {
            peopleQueue.remove(at: 0)
        }
    }
}

