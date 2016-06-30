//
//  MixpanelInstance.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/2/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import AdSupport
import CoreTelephony

public protocol MixpanelDelegate {
    func mixpanelWillFlush(_ mixpanel: MixpanelInstance) -> Bool
}

public typealias Properties = [String:AnyObject]
public typealias Queue = [Properties]

public class MixpanelInstance: FlushingDelegate, PeopleDelegate {

    public var delegate: MixpanelDelegate?
    public var distinctId: String?
    public var flushOnBackground: Bool
    public var people: People!
    public var showNetworkActivityIndicator: Bool
    public var flushInterval: Double {
        set {
            self.flushing.flushInterval = newValue
        }
        get {
            return self.flushing.flushInterval
        }
    }
    public var useIPAddressForGeoLocation: Bool {
        set {
            self.flushing.useIPAddressForGeoLocation = newValue
        }
        get {
            return self.flushing.useIPAddressForGeoLocation
        }
    }
    public var serverURL: String {
        set {
            self.flushing.serverURL = newValue
        }
        get {
            return self.flushing.serverURL
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
     var flushing: Flushing
     var tracking: Tracking

    init(apiToken: String?, launchOptions: [NSObject: AnyObject]?, flushInterval: Double) {
        if let apiToken = apiToken where apiToken.characters.count > 0 {
            self.apiToken = apiToken
        } else {
            print("warning: empty api token")
            self.apiToken = ""
        }

        self.showNetworkActivityIndicator = true
        self.taskId = UIBackgroundTaskInvalid
        self.telephonyInfo = CTTelephonyNetworkInfo()
        self.flushOnBackground = true
        self.persistence = Persistence(apiToken: self.apiToken)
        self.tracking = Tracking(apiToken: self.apiToken)
        self.flushing = Flushing()
        self.flushing.delegate = self
        let label = "com.mixpanel.\(apiToken).\(self)"
        self.serialQueue = DispatchQueue(label: label, attributes: DispatchQueueAttributes.serial)
        self.people = People(apiToken: self.apiToken, serialQueue: serialQueue)
        self.people.delegate = self
        self.automaticProperties = collectAutomaticProperties()
        self.distinctId = defaultDistinctId()
        self.flushing._flushInterval = flushInterval

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
                                       name: NSNotification.Name.CTRadioAccessTechnologyDidChange,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationWillTerminate(_:)),
                                       name: NSNotification.Name.UIApplicationWillTerminate,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationWillResignActive(_:)),
                                       name: NSNotification.Name.UIApplicationWillResignActive,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationDidBecomeActive(_:)),
                                       name: NSNotification.Name.UIApplicationDidBecomeActive,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationDidEnterBackground(_:)),
                                       name: NSNotification.Name.UIApplicationDidEnterBackground,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationWillEnterForeground(_:)),
                                       name: NSNotification.Name.UIApplicationWillEnterForeground,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(appLinksNotificationRaised(_:)),
                                       name: "com.parse.bolts.measurement_event",
                                       object: nil)
    }

    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        flushing.startFlushTimer()
    }

    @objc private func applicationWillResignActive(_ notification: Notification) {
        flushing.stopFlushTimer()
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

        if self.flushOnBackground {
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
        self.serialQueue.async(execute: {
            if self.taskId != UIBackgroundTaskInvalid {
                UIApplication.shared().endBackgroundTask(self.taskId)
                self.taskId = UIBackgroundTaskInvalid
                self.updateNetworkActivityIndicator(false)
            }
        })
    }

    @objc private func applicationWillTerminate(_ notification: Notification) {
        self.serialQueue.async(execute: {
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
            track(eventNameMap, properties:eventArgs)
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
        p["$carrier"]           = self.telephonyInfo.subscriberCellularProvider?.carrierName
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
        return "<Mixpanel: \(self) \(self.apiToken)>"
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
        self.serialQueue.async(execute: {
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

    public func identify(_ distinctId: String?) {
        guard let distinctId = distinctId where distinctId.characters.count > 0 else {
            print("\(self) cannot identify blank distinct id")
            return
        }

        self.serialQueue.async(execute: {
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

        self.track("$create_alias", properties: ["distinct_id": distinctId, "alias": alias])
        self.flush()
    }

    public func reset() {
        self.serialQueue.async(execute: {
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
        let properties = ArchivedProperties(superProperties: self.superProperties,
                                            timedEvents: self.timedEvents,
                                            distinctId: self.distinctId,
                                            peopleDistinctId: self.people.distinctId,
                                            peopleUnidentifiedQueue: self.people.unidentifiedQueue)
        persistence.archive(self.eventsQueue, peopleQueue: self.peopleQueue, properties: properties)
    }

    func unarchive() {
        (self.eventsQueue,
         self.peopleQueue,
         self.superProperties,
         self.timedEvents,
         self.distinctId,
         self.people.distinctId,
         self.people.unidentifiedQueue) = persistence.unarchive()

        if self.distinctId == nil {
            self.distinctId = defaultDistinctId()
        }
    }

    func archiveProperties() {
        let properties = ArchivedProperties(superProperties: self.superProperties,
                                            timedEvents: self.timedEvents,
                                            distinctId: self.distinctId,
                                            peopleDistinctId: self.people.distinctId,
                                            peopleUnidentifiedQueue: self.people.unidentifiedQueue)
        self.persistence.archiveProperties(properties)
    }
}

// MARK: - Flushing
extension MixpanelInstance {

    public func flush() {
        flushWithCompletion(nil)
    }

    public func flushWithCompletion(_ completion: (() -> Void)?) {
        self.serialQueue.async(execute: {
            if let shouldFlush = self.delegate?.mixpanelWillFlush(self) where !shouldFlush {
                return
            }

            self.flushing.flushEventsQueue(&self.eventsQueue)
            self.flushing.flushPeopleQueue(&self.peopleQueue)
            self.archive()

            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
        })
    }
}

// MARK: - Tracking
extension MixpanelInstance {

    public func track(_ event: String?, properties: Properties? = nil) {
        self.serialQueue.async(execute: {
            self.tracking.track(event,
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
                self.track(event, properties: ["campaign_id": c,
                                               "message_id": m,
                                               "message_type": "push"])
            } else {
                print("malformed mixpanel push payload")
            }
        }
    }

    public func timeEvent(_ event: String?) {
        self.serialQueue.async(execute: {
            self.tracking.timeEvent(event, timedEvents: &self.timedEvents)
        })
    }

    public func clearTimedEvents() {
        self.serialQueue.async(execute: {
            self.tracking.clearTimedEvents(&self.timedEvents)
        })
    }

    public func currentSuperProperties() -> Properties {
        return self.superProperties
    }

    public func clearSuperProperties() {
        self.serialQueue.async(execute: {
            self.tracking.clearSuperProperties(&self.superProperties)
            if MixpanelInstance.inBackground() {
                self.archiveProperties()
            }
        })
    }

    public func registerSuperProperties(_ properties: Properties?) {
        self.serialQueue.async(execute: {
            if let properties = properties {
                self.tracking.registerSuperProperties(properties,
                                                      superProperties: &self.superProperties)
                if MixpanelInstance.inBackground() {
                    self.archiveProperties()
                }
            }
        })
    }

    public func registerSuperPropertiesOnce(_ properties: Properties?,
                                            defaultValue: AnyObject? = nil) {
        self.serialQueue.async(execute: {
            if let properties = properties {
                self.tracking.registerSuperPropertiesOnce(properties,
                                                          superProperties: &self.superProperties,
                                                          defaultValue: defaultValue)
                if MixpanelInstance.inBackground() {
                    self.archiveProperties()
                }
            }
        })
    }

    public func unregisterSuperProperty(_ propertyName: String) {
        self.serialQueue.async(execute: {
            self.tracking.unregisterSuperProperty(propertyName,
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
        self.persistence.archivePeople(self.peopleQueue)
    }

    func addPeopleObject(_ r: Properties) {
        self.peopleQueue.append(r)
        if self.peopleQueue.count > 500 {
            self.peopleQueue.remove(at: 0)
        }
    }
}

