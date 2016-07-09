//
//  LoggerTests.swift
//  MixpanelDemo
//
//  Created by Sam Green on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation
import XCTest
@testable import Mixpanel

class LoggerTests: XCTestCase {
    var counter: CounterLogging!
    var testLog: Logger!
    
    override func setUp() {
        super.setUp()
        
        counter = CounterLogging()
        testLog = Logger(logging: counter)
    }
    
    func testEnableDebug() {
        testLog.enableLevel(level: .Debug)
        
        testLog.debug(message: "logged")
        XCTAssertEqual(1, counter.count)
    }
    
    func testEnableInfo() {
        testLog.enableLevel(level: .Info)
        
        testLog.info(message: "logged")
        XCTAssertEqual(1, counter.count)
    }
    
    func testEnableWarning() {
        testLog.enableLevel(level: .Warning)
        
        testLog.warn(message: "logged")
        XCTAssertEqual(1, counter.count)
    }
    
    func testEnableError() {
        testLog.enableLevel(level: .Error)
        
        testLog.error(message: "logged")
        XCTAssertEqual(1, counter.count)
    }
    
    func testDisabledLogging() {
        testLog.disableLevel(level: .Debug)
        testLog.debug(message: "not logged")
        XCTAssertEqual(0, counter.count)
        
        testLog.disableLevel(level: .Error)
        testLog.error(message: "not logged")
        XCTAssertEqual(0, counter.count)
        
        testLog.disableLevel(level: .Info)
        testLog.info(message: "not logged")
        XCTAssertEqual(0, counter.count)
        
        testLog.disableLevel(level: .Warning)
        testLog.warn(message: "not logged")
        XCTAssertEqual(0, counter.count)
    }
}

/// This is a stub that implements `Logging` to be passed to our `Logger` instance for testing
class CounterLogging: Logging {
    var count = 0
    
    func addMessage(message: LogMessage) {
        count = count + 1
    }
}
