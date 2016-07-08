//
//  MixpanelInstance.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/2/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

public protocol MixpanelDelegate {
    func mixpanelWillFlush(_ mixpanel: MixpanelInstance) -> Bool
}

public typealias Properties = [String:AnyObject]
public typealias Queue = [Properties]

protocol AppLifecycle {
    func applicationDidBecomeActive()
    func applicationWillResignActive()
}

public class MixpanelInstance: FlushDelegate {

    public var delegate: MixpanelDelegate?
    public var distinctId: String?
    public var people: People!
    public var showNetworkActivityIndicator = true
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
            BasePath.MixpanelAPI = newValue
        }
        get {
            return BasePath.MixpanelAPI
        }
    }
    
    var apiToken = ""
    var superProperties = Properties()
    var eventsQueue = Queue()
    var timedEvents = Properties()
    var serialQueue: DispatchQueue!
    var taskId = UIBackgroundTaskInvalid
    let automaticProperties: AutomaticProperties
    let flushInstance = Flush()
    let trackInstance: Track
    
    init(apiToken: String?, launchOptions: [NSObject: AnyObject]?, flushInterval: Double) {
        if let apiToken = apiToken where apiToken.characters.count > 0 {
            self.apiToken = apiToken
        }

        trackInstance = Track(apiToken: self.apiToken)
        automaticProperties = AutomaticProperties(apiToken: self.apiToken)
        flushInstance.delegate = self
        let label = "com.mixpanel.\(apiToken).\(self)"
        serialQueue = DispatchQueue(label: label, attributes: DispatchQueueAttributes.serial)
        people = People(apiToken: self.apiToken,
                        serialQueue: serialQueue,
                        automaticProperties: automaticProperties)
        distinctId = defaultDistinctId()
        flushInstance._flushInterval = flushInterval

        setupListeners()
        unarchive()

        if let notification =
            launchOptions?[UIApplicationLaunchOptionsRemoteNotificationKey] as? Properties {
            trackPushNotification(notification, event: "$app_open")
        }
    }

    private func setupListeners() {
        let notificationCenter = NotificationCenter.default()

        setCurrentRadio()
        notificationCenter.addObserver(self,
                                       selector: #selector(setCurrentRadio),
                                       name: .CTRadioAccessTechnologyDidChange,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationWillTerminate(_:)),
                                       name: .UIApplicationWillTerminate,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationWillResignActive(_:)),
                                       name: .UIApplicationWillResignActive,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationDidBecomeActive(_:)),
                                       name: .UIApplicationDidBecomeActive,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationDidEnterBackground(_:)),
                                       name: .UIApplicationDidEnterBackground,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationWillEnterForeground(_:)),
                                       name: .UIApplicationWillEnterForeground,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(appLinksNotificationRaised(_:)),
                                       name: "com.parse.bolts.measurement_event",
                                       object: nil)
    }
    
    deinit {
        NotificationCenter.default().removeObserver(self)
    }

    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        flushInstance.applicationDidBecomeActive()
    }

    @objc private func applicationWillResignActive(_ notification: Notification) {
        flushInstance.applicationWillResignActive()
    }

    @objc private func applicationDidEnterBackground(_ notification: Notification) {
        let sharedApplication = UIApplication.shared()
        
        taskId = sharedApplication.beginBackgroundTask() {
            self.taskId = UIBackgroundTaskInvalid
        }

        
        if flushOnBackground {
            flush()
        }

        serialQueue.async() {
            self.archive()

            if self.taskId != UIBackgroundTaskInvalid {
                sharedApplication.endBackgroundTask(self.taskId)
                self.taskId = UIBackgroundTaskInvalid
            }
        }
    }

    @objc private func applicationWillEnterForeground(_ notification: Notification) {
        serialQueue.async() {
            if self.taskId != UIBackgroundTaskInvalid {
                UIApplication.shared().endBackgroundTask(self.taskId)
                self.taskId = UIBackgroundTaskInvalid
                self.updateNetworkActivityIndicator(false)
            }
        }
    }

    @objc private func applicationWillTerminate(_ notification: Notification) {
        serialQueue.async() {
            self.archive()
        }
    }

    @objc private func appLinksNotificationRaised(_ notification: Notification) {
        let eventMap = ["al_nav_out": "$al_nav_out",
                        "al_nav_in": "$al_nav_in",
                        "al_ref_back_out": "$al_ref_back_out"]
        let userInfo = (notification as Notification).userInfo

        if let eventName = userInfo?["event_name"] as? String,
            eventArgs = userInfo?["event_args"] as? Properties,
            eventNameMap = eventMap[eventName] {
            track(event: eventNameMap, properties:eventArgs)
        }
    }

    func defaultDistinctId() -> String {
        var distinctId: String?
        if NSClassFromString("UIDevice") != nil {
            distinctId = UIDevice.current().identifierForVendor?.uuidString
        }
        
        guard let distId = distinctId else {
            return UUID().uuidString
        }

        return distId
    }

    func updateNetworkActivityIndicator(_ on: Bool) {
        if showNetworkActivityIndicator {
            UIApplication.shared().isNetworkActivityIndicatorVisible = on
        }
    }

    func description() -> String {
        return "<Mixpanel: \(self), Token: \(apiToken), Events Queue Count: \(eventsQueue.count), People Queue Count: \(people.peopleQueue.count), Distinct Id: \(distinctId)>"
    }

    @objc func setCurrentRadio() {
        let currentRadio = automaticProperties.getCurrentRadio()
        serialQueue.async() {
            self.automaticProperties.properties["$radio"] = currentRadio
        }
    }

}

// MARK: - Identity
extension MixpanelInstance {

    public func identify(distinctId: String?) {
        guard let distinctId = distinctId where distinctId.characters.count > 0 else {
            print("\(self) cannot identify blank distinct id")
            return
        }

        serialQueue.async() {
            self.distinctId = distinctId
            self.people.distinctId = distinctId
            if self.people.unidentifiedQueue.count > 0 {
                for var r in self.people.unidentifiedQueue {
                    r["$distinct_id"] = distinctId
                    self.people.peopleQueue.append(r)
                }
                self.people.unidentifiedQueue.removeAll()
                Persistence.archivePeople(self.people.peopleQueue, token: self.apiToken)
            }
            
            self.archiveProperties()
        }
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

        let properties = ["distinct_id": distinctId, "alias": alias]
        track(event: "$create_alias",
              properties: properties)
        flush()
    }

    public func reset() {
        serialQueue.async() {
            self.distinctId = self.defaultDistinctId()
            self.superProperties = Properties()
            self.eventsQueue = Queue()
            self.timedEvents = Properties()
            self.people.distinctId = nil
            self.people.peopleQueue = Queue()
            self.people.unidentifiedQueue = Queue()
            self.archive()
        }
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
        Persistence.archive(eventsQueue,
                            peopleQueue: people.peopleQueue,
                            properties: properties,
                            token: self.apiToken)
    }

    func unarchive() {
        (eventsQueue,
         people.peopleQueue,
         superProperties,
         timedEvents,
         distinctId,
         people.distinctId,
         people.unidentifiedQueue) = Persistence.unarchive(token: self.apiToken)

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
        Persistence.archiveProperties(properties, token: self.apiToken)
    }
}

// MARK: - Flush
extension MixpanelInstance {

    public func flush(completion: (() -> Void)? = nil) {
        serialQueue.async() {
            if let shouldFlush = self.delegate?.mixpanelWillFlush(self) where !shouldFlush {
                return
            }

            self.flushInstance.flushEventsQueue(&self.eventsQueue)
            self.flushInstance.flushPeopleQueue(&self.people.peopleQueue)
            self.archive()

            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
        }
    }
}

// MARK: - Track
extension MixpanelInstance {

    public func track(event: String?, properties: Properties? = nil) {
        serialQueue.async() {
            self.trackInstance.track(event: event,
                                     properties: properties,
                                     eventsQueue: &self.eventsQueue,
                                     timedEvents: &self.timedEvents,
                                     automaticProperties: self.automaticProperties.properties,
                                     superProperties: self.superProperties,
                                     distinctId: self.distinctId)
            
            Persistence.archiveEvents(self.eventsQueue, token: self.apiToken)
        }
    }

    public func trackPushNotification(_ userInfo: Properties?,
                                      event: String = "$campaign_received") {
        if let mpPayload = userInfo?["mp"] as? [String: AnyObject] {
            if let m = mpPayload["m"], c = mpPayload["c"] {
                let properties = ["campaign_id": c,
                                  "message_id": m,
                                  "message_type": "push"]
                self.track(event: event,
                           properties: properties)
            } else {
                print("malformed mixpanel push payload")
            }
        }
    }

    public func time(event: String?) {
        serialQueue.async() {
            self.trackInstance.time(event: event, timedEvents: &self.timedEvents)
        }
    }

    public func clearTimedEvents() {
        serialQueue.async() {
            self.trackInstance.clearTimedEvents(&self.timedEvents)
        }
    }

    public func currentSuperProperties() -> Properties {
        return superProperties
    }

    public func clearSuperProperties() {
        dispatchAndTrack() {
            self.trackInstance.clearSuperProperties(&self.superProperties)
        }
    }

    public func registerSuperProperties(_ properties: Properties?) {
        guard let properties = properties else {
            return
        }
        
        dispatchAndTrack() {
            self.trackInstance.registerSuperProperties(properties,
                                                       superProperties: &self.superProperties)
        }
    }

    public func registerSuperPropertiesOnce(_ properties: Properties?,
                                            defaultValue: AnyObject? = nil) {
        guard let properties = properties else {
            return
        }
        
        dispatchAndTrack() {
            self.trackInstance.registerSuperPropertiesOnce(properties,
                                                           superProperties: &self.superProperties,
                                                           defaultValue: defaultValue)
        }

    }

    public func unregisterSuperProperty(_ propertyName: String) {
        dispatchAndTrack() {
            self.trackInstance.unregisterSuperProperty(propertyName,
                                                       superProperties: &self.superProperties)
        }
    }
    
    func dispatchAndTrack(closure: () -> ()) {
        serialQueue.async() {
            closure()
            self.archiveProperties()
        }
    }
}
