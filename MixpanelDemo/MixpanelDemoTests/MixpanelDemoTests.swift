//
//  MixpanelDemoTests.swift
//  MixpanelDemoTests
//
//  Created by Yarden Eitan on 6/5/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import XCTest
import Nocilla

@testable import Mixpanel
@testable import MixpanelDemo

class MixpanelDemoTests: MixpanelBaseTests {

    func test5XXResponse() {
        _ = stubTrack().andReturn(503)
        
        self.mixpanel.track("Fake Event")

        self.mixpanel.flush()
        self.waitForSerialQueue()

        self.mixpanel.flush()
        self.waitForSerialQueue()

        // Failure count should be 3
        let waitTime =
            self.mixpanel.flushing.networkRequestsAllowedAfterTime - Date().timeIntervalSince1970
        print("Delta wait time is \(waitTime)")
        XCTAssert(waitTime >= 120, "Network backoff time is less than 2 minutes.")
        XCTAssert(self.mixpanel.flushing.networkConsecutiveFailures == 2,
                  "Network failures did not equal 2")
        XCTAssert(self.mixpanel.eventsQueue.count == 1,
                  "Removed an event from the queue that was not sent")
    }

    func testRetryAfterHTTPHeader() {
        _ = stubTrack().andReturn(200)?.withHeader("Retry-After", "60")

        self.mixpanel.track("Fake Event")

        self.mixpanel.flush()
        self.waitForSerialQueue()

        self.mixpanel.flush()
        self.waitForSerialQueue()

        // Failure count should be 3
        let waitTime =
            self.mixpanel.flushing.networkRequestsAllowedAfterTime - Date().timeIntervalSince1970
        print("Delta wait time is \(waitTime)")
        XCTAssert(fabs(60 - waitTime) < 5, "Mixpanel did not respect 'Retry-After' HTTP header")
        XCTAssert(self.mixpanel.flushing.networkConsecutiveFailures == 0,
                  "Network failures did not equal 0")
    }

    func testFlushEvents() {
        stubTrack()

        self.mixpanel.identify("d1")
        for i in 0..<50 {
            self.mixpanel.track("event \(i)")
        }

        self.flushAndWaitForSerialQueue()
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 0,
                      "events should have been flushed")

        for i in 0..<60 {
            self.mixpanel.track("evemt \(i)")
        }

        self.flushAndWaitForSerialQueue()
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 0,
                      "events should have been flushed")
    }


    func testFlushPeople() {
        stubEngage()

        self.mixpanel.identify("d1")
        for i in 0..<50 {
            self.mixpanel.people.set("p1", to: "\(i)")
        }

        self.flushAndWaitForSerialQueue()
        XCTAssertTrue(self.mixpanel.peopleQueue.count == 0, "people should have been flushed")
        for i in 0..<60 {
            self.mixpanel.people.set("p1", to: "\(i)")
        }
        self.flushAndWaitForSerialQueue()
        XCTAssertTrue(self.mixpanel.peopleQueue.count == 0, "people should have been flushed")
    }

    func testFlushNetworkFailure() {
        stubTrack().andFailWithError(
            NSError(domain: "com.mixpanel.sdk.testing", code: 1, userInfo: nil))
        self.mixpanel.identify("d1")
        for i in 0..<50 {
            self.mixpanel.track("event \(UInt(i))")
        }
        self.waitForSerialQueue()
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 50, "50 events should be queued up")
        self.flushAndWaitForSerialQueue()
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 50,
                      "events should still be in the queue if flush fails")
    }

    func testAddingEventsAfterFlush() {
        stubTrack()
        self.mixpanel.identify("d1")
        for i in 0..<10 {
            self.mixpanel.track("event \(UInt(i))")
        }
        self.waitForSerialQueue()
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 10, "10 events should be queued up")
        self.mixpanel.flush()
        for i in 0..<5 {
            self.mixpanel.track("event \(UInt(i))")
        }
        self.waitForSerialQueue()
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 5, "5 more events should be queued up")
        self.flushAndWaitForSerialQueue()
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, "events should have been flushed")
    }

    func testDropEvents() {
        self.mixpanel.delegate = self
        var events = Queue()
        for i in 0..<5000 {
            events.append(["i": i])
        }
        self.mixpanel.eventsQueue = events
        self.waitForSerialQueue()
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 5000)
        for i in 0..<5 {
            self.mixpanel.track("event", properties: ["i": 5000 + i])
        }
        self.waitForSerialQueue()
        var e: Properties = self.mixpanel.eventsQueue.last!
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 5000)
        XCTAssertEqual(e["properties"]?["i"], 5004)
    }

    func testIdentify() {
        for _ in 0..<2 {
            // run this twice to test reset works correctly wrt to distinct ids
            let distinctId: String = "d1"
            // try this for IFA, ODIN and nil
            XCTAssertEqual(self.mixpanel.distinctId,
                           self.mixpanel.defaultDistinctId(),
                           "mixpanel identify failed to set default distinct id")
            XCTAssertNil(self.mixpanel.people.distinctId,
                         "mixpanel people distinct id should default to nil")
            self.mixpanel.track("e1")
            self.waitForSerialQueue()
            XCTAssertTrue(self.mixpanel.eventsQueue.count == 1,
                          "events should be sent right away with default distinct id")
            XCTAssertEqual(self.mixpanel.eventsQueue.last?["properties"]?["distinct_id"],
                           self.mixpanel.defaultDistinctId(),
                           "events should use default distinct id if none set")
            self.mixpanel.people.set("p1", to: "a")
            self.waitForSerialQueue()
            XCTAssertTrue(self.mixpanel.peopleQueue.count == 0,
                          "people records should go to unidentified queue before identify:")
            XCTAssertTrue(self.mixpanel.people.unidentifiedQueue.count == 1,
                          "unidentified people records not queued")
            XCTAssertEqual(self.mixpanel.people.unidentifiedQueue.last?["$token"] as? String,
                           kTestToken,
                           "incorrect project token in people record")
            self.mixpanel.identify(distinctId)
            self.waitForSerialQueue()
            XCTAssertEqual(self.mixpanel.distinctId, distinctId,
                           "mixpanel identify failed to set distinct id")
            XCTAssertEqual(self.mixpanel.people.distinctId, distinctId,
                           "mixpanel identify failed to set people distinct id")
            XCTAssertTrue(self.mixpanel.people.unidentifiedQueue.count == 0,
                          "identify: should move records from unidentified queue")
            XCTAssertTrue(self.mixpanel.peopleQueue.count == 1,
                          "identify: should move records to main people queue")
            XCTAssertEqual(self.mixpanel.peopleQueue.last?["$token"] as? String,
                           kTestToken, "incorrect project token in people record")
            XCTAssertEqual(self.mixpanel.peopleQueue.last?["$distinct_id"] as? String,
                           distinctId, "distinct id not set properly on unidentified people record")
            var p: Properties = self.mixpanel.peopleQueue.last?["$set"] as! Properties
            XCTAssertEqual(p["p1"] as? String, "a", "custom people property not queued")
            self.assertDefaultPeopleProperties(p)
            self.mixpanel.people.set("p1", to: "a")
            self.waitForSerialQueue()
            XCTAssertTrue(self.mixpanel.people.unidentifiedQueue.count == 0,
                          "once idenitfy: is called, unidentified queue should be skipped")
            XCTAssertTrue(self.mixpanel.peopleQueue.count == 2,
                          "once identify: is called, records should go straight to main queue")
            self.mixpanel.track("e2")
            self.waitForSerialQueue()
            let newDistinctId = self.mixpanel.eventsQueue.last?["properties"]?["distinct_id"]
            XCTAssertEqual(newDistinctId, distinctId,
                           "events should use new distinct id after identify:")
            self.mixpanel.reset()
            self.waitForSerialQueue()
        }
    }
    func testTrackWithDefaultProperties() {
        self.mixpanel.track("Something Happened")
        self.waitForSerialQueue()
        var e: Properties = self.mixpanel.eventsQueue.last!
        XCTAssertEqual(e["event"] as? String, "Something Happened", "incorrect event name")
        var p: Properties = e["properties"] as! [String: AnyObject]
        XCTAssertNotNil(p["$app_version"], "$app_version not set")
        XCTAssertNotNil(p["$app_release"], "$app_release not set")
        XCTAssertNotNil(p["$lib_version"], "$lib_version not set")
        XCTAssertNotNil(p["$model"], "$model not set")
        XCTAssertNotNil(p["$os"], "$os not set")
        XCTAssertNotNil(p["$os_version"], "$os_version not set")
        XCTAssertNotNil(p["$screen_height"], "$screen_height not set")
        XCTAssertNotNil(p["$screen_width"], "$screen_width not set")
        XCTAssertNotNil(p["distinct_id"], "distinct_id not set")
        XCTAssertNotNil(p["mp_device_model"], "mp_device_model not set")
        XCTAssertNotNil(p["time"], "time not set")
        XCTAssertEqual(p["$manufacturer"] as? String, "Apple", "incorrect $manufacturer")
        XCTAssertEqual(p["mp_lib"] as? String, "iphone", "incorrect mp_lib")
        XCTAssertEqual(p["token"] as? String, kTestToken, "incorrect token")
    }

    func testTrackWithCustomProperties() {
        let now = Date()
        let p: Properties = ["string": "yello",
                             "number": 3,
                             "date": now,
                             "$app_version": "override"]
        self.mixpanel.track("Something Happened", properties: p)
        self.waitForSerialQueue()
        var props: Properties = self.mixpanel.eventsQueue.last?["properties"] as! Properties
        XCTAssertEqual(props["string"] as? String, "yello")
        XCTAssertEqual(props["number"] as? Int, 3)
        XCTAssertEqual(props["date"] as? Date, now)
        XCTAssertEqual(props["$app_version"] as? String, "override",
                       "reserved property override failed")
    }

    func testTrackWithCustomDistinctIdAndToken() {
        let p: Properties = ["token": "t1", "distinct_id": "d1"]
        self.mixpanel.track("e1", properties: p)
        self.waitForSerialQueue()
        let trackToken = self.mixpanel.eventsQueue.last?["properties"]?["token"]!
        let trackDistinctId = self.mixpanel.eventsQueue.last?["properties"]?["distinct_id"]!
        XCTAssertEqual(trackToken, "t1", "user-defined distinct id not used in track.")
        XCTAssertEqual(trackDistinctId, "d1", "user-defined distinct id not used in track.")
    }

    func testRegisterSuperProperties() {
        var p: Properties = ["p1": "a", "p2": 3, "p3": Date()]
        self.mixpanel.registerSuperProperties(p)
        self.waitForSerialQueue()
        XCTAssertEqual(NSDictionary(dictionary: self.mixpanel.currentSuperProperties()),
                       NSDictionary(dictionary: p),
                       "register super properties failed")
        p = ["p1": "b"]
        self.mixpanel.registerSuperProperties(p)
        self.waitForSerialQueue()
        XCTAssertEqual(self.mixpanel.currentSuperProperties()["p1"] as? String, "b",
                       "register super properties failed to overwrite existing value")
        p = ["p4": "a"]
        self.mixpanel.registerSuperPropertiesOnce(p)
        self.waitForSerialQueue()
        XCTAssertEqual(self.mixpanel.currentSuperProperties()["p4"] as? String, "a",
                       "register super properties once failed first time")
        p = ["p4": "b"]
        self.mixpanel.registerSuperPropertiesOnce(p)
        self.waitForSerialQueue()
        XCTAssertEqual(self.mixpanel.currentSuperProperties()["p4"] as? String, "a",
                       "register super properties once failed second time")
        p = ["p4": "c"]
        self.mixpanel.registerSuperPropertiesOnce(p, defaultValue: "d")
        self.waitForSerialQueue()
        XCTAssertEqual(self.mixpanel.currentSuperProperties()["p4"] as? String, "a",
                       "register super properties once with default value failed when no match")
        self.mixpanel.registerSuperPropertiesOnce(p, defaultValue: "a")
        self.waitForSerialQueue()
        XCTAssertEqual(self.mixpanel.currentSuperProperties()["p4"] as? String, "c",
                       "register super properties once with default value failed when match")
        self.mixpanel.unregisterSuperProperty("a")
        self.waitForSerialQueue()
        XCTAssertNil(self.mixpanel.currentSuperProperties()["a"],
                     "unregister super property failed")
        // unregister non-existent super property should not throw
        self.mixpanel.unregisterSuperProperty("a")
        self.mixpanel.clearSuperProperties()
        self.waitForSerialQueue()
        XCTAssertTrue(self.mixpanel.currentSuperProperties().count == 0,
                      "clear super properties failed")
    }

    func testInvalidPropertiesTrack() {
        let p: Properties = ["data": Data()]
        XCTExpectAssert("property type should not be allowed") {
            self.mixpanel.track("e1", properties: p)
        }
    }

    func testInvalidSuperProperties() {
        let p: Properties = ["data": Data()]
        XCTExpectAssert("property type should not be allowed") {
            self.mixpanel.registerSuperProperties(p)
        }
        XCTExpectAssert("property type should not be allowed") {
            self.mixpanel.registerSuperPropertiesOnce(p)
        }
        XCTExpectAssert("property type should not be allowed") {
            self.mixpanel.registerSuperPropertiesOnce(p, defaultValue: "v")
        }
    }

    func testValidPropertiesTrack() {
        let p: Properties = self.allPropertyTypes()
        self.mixpanel.track("e1", properties: p)
    }

    func testValidSuperProperties() {
        let p: Properties = self.allPropertyTypes()
        self.mixpanel.registerSuperProperties(p)
        self.mixpanel.registerSuperPropertiesOnce(p)
        self.mixpanel.registerSuperPropertiesOnce(p, defaultValue: "v")
    }

    func testTrackLaunchOptions() {
        let launchOptions: Properties = [UIApplicationLaunchOptionsRemoteNotificationKey: ["mp":
            ["m": "the_message_id", "c": "the_campaign_id"]]]
        self.mixpanel = Mixpanel.initWithToken(kTestToken,
                                               launchOptions: launchOptions,
                                               flushInterval: 60)
        self.waitForSerialQueue()
        var e: Properties = self.mixpanel.eventsQueue.last!
        XCTAssertEqual(e["event"] as? String, "$app_open", "incorrect event name")
        var p: Properties = e["properties"] as! Properties
        XCTAssertEqual(p["campaign_id"] as? String, "the_campaign_id", "campaign_id not equal")
        XCTAssertEqual(p["message_id"] as? String, "the_message_id", "message_id not equal")
        XCTAssertEqual(p["message_type"] as? String, "push", "type does not equal inapp")
    }

    func testTrackPushNotification() {
        self.mixpanel.trackPushNotification(["mp": ["m": "the_message_id", "c": "the_campaign_id"]])
        self.waitForSerialQueue()
        var e: Properties = self.mixpanel.eventsQueue.last!
        XCTAssertEqual(e["event"] as? String, "$campaign_received", "incorrect event name")
        var p: Properties = e["properties"] as! Properties
        XCTAssertEqual(p["campaign_id"] as? String, "the_campaign_id", "campaign_id not equal")
        XCTAssertEqual(p["message_id"] as? String, "the_message_id", "message_id not equal")
        XCTAssertEqual(p["message_type"] as? String, "push", "type does not equal inapp")
    }

    func testTrackPushNotificationMalformed() {
        self.mixpanel.trackPushNotification(["mp":
            ["m": "the_message_id", "cid": "the_campaign_id"]])
        self.waitForSerialQueue()
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 0,
                      "Invalid push notification was incorrectly queued.")
        self.mixpanel.trackPushNotification(["mp": 1])
        self.waitForSerialQueue()
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 0,
                      "Invalid push notification was incorrectly queued.")
        self.mixpanel.trackPushNotification(nil)
        self.waitForSerialQueue()
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 0,
                      "Invalid push notification was incorrectly queued.")
        self.mixpanel.trackPushNotification([:])
        self.waitForSerialQueue()
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 0,
                      "Invalid push notification was incorrectly queued.")
        self.mixpanel.trackPushNotification(["mp": "bad value"])
        self.waitForSerialQueue()
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 0,
                      "Invalid push notification was incorrectly queued.")
        self.waitForSerialQueue()
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 0,
                      "Invalid push notification was incorrectly queued.")
    }

    func testReset() {
        self.mixpanel.identify("d1")
        self.mixpanel.track("e1")
        let p: Properties = ["p1": "a"]
        self.mixpanel.registerSuperProperties(p)
        self.mixpanel.people.set(p)
        self.mixpanel.archive()
        self.mixpanel.reset()
        self.waitForSerialQueue()
        XCTAssertEqual(self.mixpanel.distinctId,
                       self.mixpanel.defaultDistinctId(),
                       "distinct id failed to reset")
        XCTAssertNil(self.mixpanel.people.distinctId, "people distinct id failed to reset")
        XCTAssertTrue(self.mixpanel.currentSuperProperties().count == 0,
                      "super properties failed to reset")
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, "events queue failed to reset")
        XCTAssertTrue(self.mixpanel.peopleQueue.count == 0, "people queue failed to reset")
        self.mixpanel = Mixpanel.initWithToken(kTestToken, launchOptions: nil, flushInterval: 60)
        self.waitForSerialQueue()
        XCTAssertEqual(self.mixpanel.distinctId, self.mixpanel.defaultDistinctId(),
                       "distinct id failed to reset after archive")
        XCTAssertNil(self.mixpanel.people.distinctId,
                     "people distinct id failed to reset after archive")
        XCTAssertTrue(self.mixpanel.currentSuperProperties().count == 0,
                      "super properties failed to reset after archive")
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 0,
                      "events queue failed to reset after archive")
        XCTAssertTrue(self.mixpanel.peopleQueue.count == 0,
                      "people queue failed to reset after archive")
    }

    func testArchive() {
        self.mixpanel.archive()
        self.mixpanel = Mixpanel.initWithToken(kTestToken, launchOptions: nil, flushInterval: 60)
        XCTAssertEqual(self.mixpanel.distinctId, self.mixpanel.defaultDistinctId(),
                       "default distinct id archive failed")
        XCTAssertTrue(self.mixpanel.currentSuperProperties().count == 0,
                      "default super properties archive failed")
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, "default events queue archive failed")
        XCTAssertNil(self.mixpanel.people.distinctId, "default people distinct id archive failed")
        XCTAssertTrue(self.mixpanel.peopleQueue.count == 0, "default people queue archive failed")
        let p: Properties = ["p1": "a"]
        self.mixpanel.identify("d1")
        self.mixpanel.registerSuperProperties(p)
        self.mixpanel.track("e1")
        self.mixpanel.people.set(p)
        self.mixpanel.timedEvents["e2"] = 5.0
        self.waitForSerialQueue()
        self.mixpanel.archive()
        self.mixpanel = Mixpanel.initWithToken(kTestToken, launchOptions: nil, flushInterval: 60)
        self.waitForSerialQueue()
        XCTAssertEqual(self.mixpanel.distinctId, "d1", "custom distinct archive failed")
        XCTAssertTrue(self.mixpanel.currentSuperProperties().count == 1,
                      "custom super properties archive failed")
        XCTAssertEqual(self.mixpanel.eventsQueue.last?["event"] as? String, "e1",
                       "event was not successfully archived/unarchived")
        XCTAssertEqual(self.mixpanel.people.distinctId, "d1",
                       "custom people distinct id archive failed")
        XCTAssertTrue(self.mixpanel.peopleQueue.count == 1, "pending people queue archive failed")
        XCTAssertEqual(self.mixpanel.timedEvents["e2"] as? Double, 5.0,
                       "timedEvents archive failed")
        let fileManager = FileManager.default()
        XCTAssertTrue(fileManager.fileExists(
            atPath: self.mixpanel.persistence.filePathWithType(.Events)!),
                      "events archive file not removed")
        XCTAssertTrue(fileManager.fileExists(
            atPath: self.mixpanel.persistence.filePathWithType(.People)!),
                      "people archive file not removed")
        XCTAssertTrue(fileManager.fileExists(
            atPath: self.mixpanel.persistence.filePathWithType(.Properties)!),
                      "properties archive file not removed")
        self.mixpanel = Mixpanel.initWithToken(kTestToken, launchOptions: nil, flushInterval: 60)
        XCTAssertEqual(self.mixpanel.distinctId, "d1", "expecting d1 as distinct id as initialised")
        XCTAssertTrue(self.mixpanel.currentSuperProperties().count == 1,
                      "default super properties expected to have 1 item")
        XCTAssertNotNil(self.mixpanel.eventsQueue, "default events queue from no file is nil")
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 1, "default events queue expecting 1 item")
        XCTAssertNotNil(self.mixpanel.people.distinctId,
                        "default people distinct id from no file failed")
        XCTAssertNotNil(self.mixpanel.peopleQueue, "default people queue from no file is nil")
        XCTAssertTrue(self.mixpanel.peopleQueue.count == 1, "default people queue expecting 1 item")
        XCTAssertTrue(self.mixpanel.timedEvents.count == 1, "timedEvents expecting 1 item")
        // corrupt file
        let garbage = "garbage".data(using: String.Encoding.utf8)!
        do {
            try garbage.write(to: URL(
                fileURLWithPath: self.mixpanel.persistence.filePathWithType(.Events)!),
                              options: [])
            try garbage.write(to: URL(
                fileURLWithPath: self.mixpanel.persistence.filePathWithType(.People)!),
                              options: [])
            try garbage.write(to: URL(
                fileURLWithPath: self.mixpanel.persistence.filePathWithType(.Properties)!),
                              options: [])
        } catch {
            print("couldn't write data")
        }
        XCTAssertTrue(fileManager.fileExists(
            atPath: self.mixpanel.persistence.filePathWithType(.Events)!),
                      "events archive file not removed")
        XCTAssertTrue(fileManager.fileExists(
            atPath: self.mixpanel.persistence.filePathWithType(.People)!),
                      "people archive file not removed")
        XCTAssertTrue(fileManager.fileExists(
            atPath: self.mixpanel.persistence.filePathWithType(.Properties)!),
                      "properties archive file not removed")
        self.mixpanel = Mixpanel.initWithToken(kTestToken, launchOptions: nil, flushInterval: 60)
        self.waitForSerialQueue()
        XCTAssertEqual(self.mixpanel.distinctId, self.mixpanel.defaultDistinctId(),
                       "default distinct id from garbage failed")
        XCTAssertTrue(self.mixpanel.currentSuperProperties().count == 0,
                      "default super properties from garbage failed")
        XCTAssertNotNil(self.mixpanel.eventsQueue, "default events queue from garbage is nil")
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 0,
                      "default events queue from garbage not empty")
        XCTAssertNil(self.mixpanel.people.distinctId,
                     "default people distinct id from garbage failed")
        XCTAssertNotNil(self.mixpanel.peopleQueue,
                        "default people queue from garbage is nil")
        XCTAssertTrue(self.mixpanel.peopleQueue.count == 0,
                      "default people queue from garbage not empty")
        XCTAssertTrue(self.mixpanel.timedEvents.count == 0,
                      "timedEvents is not empty")
    }

    func testMixpanelDelegate() {
        self.mixpanel.delegate = self
        self.mixpanel.identify("d1")
        self.mixpanel.track("e1")
        self.mixpanel.people.set("p1", to: "a")
        self.mixpanel.flush()
        self.waitForSerialQueue()
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 1, "delegate should have stopped flush")
        XCTAssertTrue(self.mixpanel.peopleQueue.count == 1, "delegate should have stopped flush")
    }

    func testNilArguments() {
        let originalDistinctID: String = self.mixpanel.distinctId!
        self.mixpanel.identify(nil)
        XCTAssertEqual(self.mixpanel.distinctId, originalDistinctID,
                       "identify nil should do nothing.")
        self.mixpanel.track(nil)
        self.mixpanel.track(nil, properties: nil)
        self.mixpanel.registerSuperProperties(nil)
        self.mixpanel.registerSuperPropertiesOnce(nil)
        self.mixpanel.registerSuperPropertiesOnce(nil, defaultValue: nil)
        self.waitForSerialQueue()
        // legacy behavior
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 2,
                      "track with nil should create mp_event event")
        XCTAssertEqual(self.mixpanel.eventsQueue.last?["event"] as? String,
                       "mp_event", "track with nil should create mp_event event")
        XCTAssertNotNil(self.mixpanel.currentSuperProperties(),
                        "setting super properties to nil should have no effect")
        XCTAssertTrue(self.mixpanel.currentSuperProperties().count == 0,
                      "setting super properties to nil should have no effect")
        XCTExpectAssert("should not take nil argument") {
            self.mixpanel.people.set(nil)
        }
        XCTExpectAssert("should not take nil argument") {
            self.mixpanel.people.set(nil, to: "a")
        }
        XCTExpectAssert("should not take nil argument") {
            self.mixpanel.people.set("p1", to: nil)
        }
        XCTExpectAssert("should not take nil argument") {
            self.mixpanel.people.increment(nil)
        }
        XCTExpectAssert("should not take nil argument") {
            self.mixpanel.people.increment(nil, by: 3)
        }
        XCTExpectAssert("should not take nil argument") {
            self.mixpanel.people.increment("p1", by: nil)
        }
    }

    func testEventTiming() {
        self.mixpanel.track("Something Happened")
        self.waitForSerialQueue()
        var e: Properties = self.mixpanel.eventsQueue.last!
        var p = e["properties"] as! Properties
        XCTAssertNil(p["$duration"], "New events should not be timed.")
        self.mixpanel.timeEvent("400 Meters")
        self.mixpanel.track("500 Meters")
        self.waitForSerialQueue()
        e = self.mixpanel.eventsQueue.last!
        p = e["properties"] as! Properties
        XCTAssertNil(p["$duration"], "The exact same event name is required for timing.")
        self.mixpanel.track("400 Meters")
        self.waitForSerialQueue()
        e = self.mixpanel.eventsQueue.last!
        p = e["properties"] as! Properties
        XCTAssertNotNil(p["$duration"], "This event should be timed.")
        self.mixpanel.track("400 Meters")
        self.waitForSerialQueue()
        e = self.mixpanel.eventsQueue.last!
        p = e["properties"] as! Properties
        XCTAssertNil(p["$duration"],
                     "Tracking the same event should require a second call to timeEvent.")
    }

    func testNetworkingWithStress() {
        _ = stubTrack().andReturn(503)
        for _ in 0..<500 {
            self.mixpanel.track("Track Call")
        }
        self.flushAndWaitForSerialQueue()
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 500, "none supposed to be flushed")
        LSNocilla.sharedInstance().clearStubs()
        _ = stubTrack().andReturn(200)
        self.mixpanel.flushing.networkRequestsAllowedAfterTime = 0
        self.flushAndWaitForSerialQueue()
        XCTAssertTrue(self.mixpanel.eventsQueue.count == 0, "supposed to all be flushed")
    }

    func testTelephonyInfoInitialized() {
        XCTAssertNotNil(self.mixpanel.telephonyInfo, "telephonyInfo wasn't initialized")
    }
}
