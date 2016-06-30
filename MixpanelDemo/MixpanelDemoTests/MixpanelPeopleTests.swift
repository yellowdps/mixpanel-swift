//
//  MixpanelPeopleTests.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 6/28/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import XCTest
import Nocilla

@testable import Mixpanel
@testable import MixpanelDemo

class MixpanelPeopleTests: MixpanelBaseTests {

    func testPeopleSet() {
        self.mixpanel.identify("d1")
        var p: Properties = ["p1": "a"]
        self.mixpanel.people.set(p)
        self.waitForSerialQueue()
        p = self.mixpanel.peopleQueue.last!["$set"] as! Properties
        XCTAssertEqual(p["p1"] as? String, "a", "custom people property not queued")
        self.assertDefaultPeopleProperties(p)
    }

    func testPeopleSetOnce() {
        self.mixpanel.identify("d1")
        var p: Properties = ["p1": "a"]
        self.mixpanel.people.setOnce(p)
        self.waitForSerialQueue()
        p = self.mixpanel.peopleQueue.last!["$set_once"] as! Properties
        XCTAssertEqual(p["p1"] as? String, "a", "custom people property not queued")
        self.assertDefaultPeopleProperties(p)
    }

    func testPeopleSetReservedProperty() {
        self.mixpanel.identify("d1")
        var p: Properties = ["$ios_app_version": "override"]
        self.mixpanel.people.set(p)
        self.waitForSerialQueue()
        p = self.mixpanel.peopleQueue.last!["$set"] as! Properties
        XCTAssertEqual(p["$ios_app_version"] as? String,
                       "override",
                       "reserved property override failed")
        self.assertDefaultPeopleProperties(p)
    }

    func testPeopleSetTo() {
        self.mixpanel.identify("d1")
        self.mixpanel.people.set("p1", to: "a")
        self.waitForSerialQueue()
        var p: Properties = self.mixpanel.peopleQueue.last!["$set"] as! Properties
        XCTAssertEqual(p["p1"] as? String, "a", "custom people property not queued")
        self.assertDefaultPeopleProperties(p)
    }

    func testDropUnidentifiedPeopleRecords() {
        for i in 0..<505 {
            self.mixpanel.people.set("i", to: i)
        }
        self.waitForSerialQueue()
        XCTAssertTrue(self.mixpanel.people.unidentifiedQueue.count == 500)
        var r: Properties = self.mixpanel.people.unidentifiedQueue.first!
        XCTAssertEqual(r["$set"]?["i"], 5)
        r = self.mixpanel.people.unidentifiedQueue.last!
        XCTAssertEqual(r["$set"]?["i"], 504)
    }

    func testDropPeopleRecords() {
        self.mixpanel.identify("d1")
        for i in 0..<505 {
            self.mixpanel.people.set("i", to: i)
        }
        self.waitForSerialQueue()
        XCTAssertTrue(self.mixpanel.peopleQueue.count == 500)
        var r: Properties = self.mixpanel.peopleQueue.first!
        XCTAssertEqual(r["$set"]?["i"], 5)
        r = self.mixpanel.peopleQueue.last!
        XCTAssertEqual(r["$set"]?["i"], 504)
    }

    func testPeopleAssertPropertyTypes() {
        var p: Properties = ["URL": Data()]
        XCTExpectAssert("unsupported property type was allowed") {
            self.mixpanel.people.set(p)
        }
        XCTExpectAssert("unsupported property type was allowed") {
            self.mixpanel.people.set("p1", to: Data())
        }
        p = ["p1": "a"]
        // increment should require a number
        XCTExpectAssert("unsupported property type was allowed") {
            self.mixpanel.people.increment(p)
        }
    }

    func testPeopleAddPushDeviceToken() {
        self.mixpanel.identify("d1")
        let token: Data = "0123456789abcdef".data(using: String.Encoding.utf8)!
        self.mixpanel.people.addPushDeviceToken(token)
        self.waitForSerialQueue()
        XCTAssertTrue(self.mixpanel.peopleQueue.count == 1, "people records not queued")
        var p: Properties = self.mixpanel.peopleQueue.last!["$union"] as! Properties
        XCTAssertTrue(p.count == 1, "incorrect people properties: \(p)")
        let a: [AnyObject] = p["$ios_devices"] as! [AnyObject]
        XCTAssertTrue(a.count == 1, "device token array not set")
        XCTAssertEqual(a.last as? String,
                       "30313233343536373839616263646566",
                       "device token not encoded properly")
    }

    func testPeopleIncrement() {
        self.mixpanel.identify("d1")
        var p: Properties = ["p1": 3]
        self.mixpanel.people.increment(p)
        self.waitForSerialQueue()
        p = self.mixpanel.peopleQueue.last!["$add"] as! Properties
        XCTAssertTrue(p.count == 1, "incorrect people properties: \(p)")
        XCTAssertEqual(p["p1"] as? Int, 3, "custom people property not queued")
    }

    func testPeopleIncrementBy() {
        self.mixpanel.identify("d1")
        self.mixpanel.people.increment("p1", by: 3)
        self.waitForSerialQueue()
        var p: Properties = self.mixpanel.peopleQueue.last!["$add"] as! Properties
        XCTAssertTrue(p.count == 1, "incorrect people properties: \(p)")
        XCTAssertEqual(p["p1"] as? Int, 3, "custom people property not queued")
    }

    func testPeopleDeleteUser() {
        self.mixpanel.identify("d1")
        self.mixpanel.people.deleteUser()
        self.waitForSerialQueue()
        let p: Properties = self.mixpanel.peopleQueue.last!["$delete"] as! Properties
        XCTAssertTrue(p.count == 0, "incorrect people properties: \(p)")
    }


    func testPeopleTrackChargeDecimal() {
        self.mixpanel.identify("d1")
        self.mixpanel.people.trackCharge(25.34)
        self.waitForSerialQueue()
        var r: Properties = self.mixpanel.peopleQueue.last!
        let prop = ((r["$append"] as? Properties)?["$transactions"] as? Properties)?["$amount"] as? Double
        let prop2 = ((r["$append"] as? Properties)?["$transactions"] as? Properties)?["$time"]
        XCTAssertEqual(prop, 25.34)
        XCTAssertNotNil(prop2)
    }

    func testPeopleTrackChargeNil() {
        self.mixpanel.identify("d1")
        XCTExpectAssert("can't have nil as trackCharge") {
            self.mixpanel.people.trackCharge(nil)
        }
        XCTAssertTrue(self.mixpanel.peopleQueue.count == 0)
    }

    func testPeopleTrackChargeZero() {
        self.mixpanel.identify("d1")
        self.mixpanel.people.trackCharge(0)
        self.waitForSerialQueue()
        var r: Properties = self.mixpanel.peopleQueue.last!
        let prop = ((r["$append"] as? Properties)?["$transactions"] as? Properties)?["$amount"] as? Double
        let prop2 = ((r["$append"] as? Properties)?["$transactions"] as? Properties)?["$time"]
        XCTAssertEqual(prop, 0)
        XCTAssertNotNil(prop2)
    }
    func testPeopleTrackChargeWithTime() {
        self.mixpanel.identify("d1")
        var p: Properties = self.allPropertyTypes()
        self.mixpanel.people.trackCharge(25, properties: ["$time": p["date"]!])
        self.waitForSerialQueue()
        var r: Properties = self.mixpanel.peopleQueue.last!
        let prop = ((r["$append"] as? Properties)?["$transactions"] as? Properties)?["$amount"] as? Double
        let prop2 = ((r["$append"] as? Properties)?["$transactions"] as? Properties)?["$time"]
        XCTAssertEqual(prop, 25)
        XCTAssertEqual(prop2 as? Date, p["date"] as? Date)
    }

    func testPeopleTrackChargeWithProperties() {
        self.mixpanel.identify("d1")
        self.mixpanel.people.trackCharge(25, properties: ["p1": "a"])
        self.waitForSerialQueue()
        var r: Properties = self.mixpanel.peopleQueue.last!
        let prop = ((r["$append"] as? Properties)?["$transactions"] as? Properties)?["$amount"] as? Double
        let prop2 = ((r["$append"] as? Properties)?["$transactions"] as? Properties)?["p1"]
        XCTAssertEqual(prop, 25)
        XCTAssertEqual(prop2 as? String, "a")
    }

    func testPeopleTrackCharge() {
        self.mixpanel.identify("d1")
        self.mixpanel.people.trackCharge(25)
        self.waitForSerialQueue()
        var r: Properties = self.mixpanel.peopleQueue.last!
        let prop = ((r["$append"] as? Properties)?["$transactions"] as? Properties)?["$amount"] as? Double
        let prop2 = ((r["$append"] as? Properties)?["$transactions"] as? Properties)?["$time"]
        XCTAssertEqual(prop, 25)
        XCTAssertNotNil(prop2)
    }

    func testPeopleClearCharges() {
        self.mixpanel.identify("d1")
        self.mixpanel.people.clearCharges()
        self.waitForSerialQueue()
        var r: Properties = self.mixpanel.peopleQueue.last!
        XCTAssertEqual(r["$set"]?["$transactions"], [])
    }
}
