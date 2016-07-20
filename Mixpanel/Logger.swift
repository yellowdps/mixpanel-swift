//
//  Logger.swift
//  Logger
//
//  Created by Sam Green on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

/// This defines the various levels of logging that a message may be tagged with. This allows hiding and
/// showing different logging levels at run time depending on the environment
enum LogLevel: String {
    /// Logging displays *all* logs and additional debug information that may be useful to a developer
    case Debug
    
    /// Logging displays *all* logs (**except** debug)
    case Info
    
    /// Logging displays *only* warnings and above
    case Warning
    
    /// Logging displays *only* errors and above
    case Error
}

/// This holds all the data for each log message, since the formatting is up to each
/// logging object. It is a simple bag of data
struct LogMessage {
    /// The file where this log message was created
    let file: String
    
    /// The function where this log message was created
    let function: String
    
    /// The text of the log message
    let text: String
    
    /// The level of the log message
    let level: LogLevel
    
    init(path: String, function: String, text: String, level: LogLevel) {
        if let file = path.componentsSeparatedByString("/").last {
            self.file = file
        } else {
            self.file = path
        }
        self.function = function
        self.text = text
        self.level = level
    }
}

/// Any object that conforms to this protocol may log messages
protocol Logging {
    func addMessage(message message: LogMessage)
}

class Logger {
    private static var loggers = [Logging]()
    private static var enabledLevels = Set<LogLevel>()
    
    /// Add a `Logging` object to receive all log messages
    class func addLogging(logging: Logging) {
        loggers.append(logging)
    }
    
    /// Enable log messages of a specific `LogLevel` to be added to the log
    class func enableLevel(level: LogLevel) {
        enabledLevels.insert(level)
    }
    
    /// Disable log messages of a specific `LogLevel` to prevent them from being logged
    class func disableLevel(level: LogLevel) {
        enabledLevels.remove(level)
    }
    
    
    /// The lowest priority, and normally not logged except for code based messages.
    class func debug(@autoclosure message message: () -> Any, _ path: String = #file, _ function: String = #function) {
        guard enabledLevels.contains(.Debug) else { return }
        forwardLogMessage(LogMessage(path: path, function: function, text: "\(message())",
                                              level: .Debug))
    }

    /// The lowest priority that you would normally log, and purely informational in nature.
    class func info(@autoclosure message message: () -> Any, _ path: String = #file, _ function: String = #function) {
        guard enabledLevels.contains(.Info) else { return }
        forwardLogMessage(LogMessage(path: path, function: function, text: "\(message())",
                                              level: .Info))
    }
    
    /// Something is amiss and might fail if not corrected.
    class func warn(@autoclosure message message: () -> Any, _ path: String = #file, _ function: String = #function) {
        guard enabledLevels.contains(.Warning) else { return }
        forwardLogMessage(LogMessage(path: path, function: function, text: "\(message())",
                                              level: .Warning))
    }
    
    /// Something has failed.
    class func error(@autoclosure message message: () -> Any, _ path: String = #file, _ function: String = #function) {
        guard enabledLevels.contains(.Error) else { return }
        forwardLogMessage(LogMessage(path: path, function: function, text: "\(message())",
                                               level: .Error))
    }
    
    /// This forwards a `LogMessage` to each logger that has been added
    class private func forwardLogMessage(message: LogMessage) {
        // Forward the log message to every registered Logging instance
        loggers.forEach() { $0.addMessage(message: message) }
    }
}
