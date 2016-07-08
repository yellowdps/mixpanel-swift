//
//  LogMessage.swift
//  MPLogger
//
//  Created by Sam Green on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

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
        if let file = path.components(separatedBy: "/").last {
            self.file = file
        } else {
            self.file = path
        }
        self.function = function
        self.text = text
        self.level = level
    }
}
