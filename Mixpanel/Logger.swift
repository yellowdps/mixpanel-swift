//
//  MPLogger.swift
//  MPLogger
//
//  Created by Sam Green on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

let Log = Logger(logging: PrintLogging())

class Logger {
    // MARK: Private
    private var loggers = [Logging]()
    private var enabledLevels = Set<LogLevel>()
    
    init(logging: Logging) {
        addLogging(logging: logging)
    }
    
    /// Add a `Logging` object to receive all log messages
    func addLogging(logging: Logging) {
        loggers.append(logging)
    }
    
    /// Enable log messages of a specific `LogLevel` to be added to the log
    func enableLevel(level: LogLevel) {
        enabledLevels.insert(level)
    }
    
    /// Disable log messages of a specific `LogLevel` to prevent them from being logged
    func disableLevel(level: LogLevel) {
        enabledLevels.remove(level)
    }
    
    /// debug: Adds a debug message to the Mixpanel log
    /// - Parameter message: The message to be added to the log
    func debug(message: @autoclosure() -> Any, _ path: String = #file, _ function: String = #function) {
        guard enabledLevels.contains(.Debug) else { return }
        forwardLogMessage(message: LogMessage(path: path, function: function, text: "\(message())",
                                              level: .Debug))
    }

    /// info: Adds an informational message to the Mixpanel log
    /// - Parameter message: The message to be added to the log
    func info(message: @autoclosure() -> Any, _ path: String = #file, _ function: String = #function) {
        guard enabledLevels.contains(.Info) else { return }
        forwardLogMessage(message: LogMessage(path: path, function: function, text: "\(message())",
                                              level: .Info))
    }
    
    /// warn: Adds a warning message to the Mixpanel log
    /// - Parameter message: The message to be added to the log
    func warn(message: @autoclosure() -> Any, _ path: String = #file, _ function: String = #function) {
        guard enabledLevels.contains(.Warning) else { return }
        forwardLogMessage(message: LogMessage(path: path, function: function, text: "\(message())",
                                              level: .Warning))
    }
    
    /// error: Adds an error message to the Mixpanel log
    /// - Parameter message: The message to be added to the log
    func error(message: @autoclosure() -> Any, _ path: String = #file, _ function: String = #function) {
        guard enabledLevels.contains(.Error) else { return }
        forwardLogMessage(message: LogMessage(path: path, function: function, text: "\(message())",
                                               level: .Error))
    }
    
    /// This forwards a `LogMessage` to each logger that has been added
    private func forwardLogMessage(message: LogMessage) {
        // Forward the log message to every registered Logging instance
        loggers.forEach() { $0.addMessage(message: message) }
    }
}
