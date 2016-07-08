//
//  LogLevel.swift
//  MPLogger
//
//  Created by Sam Green on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

/// This defines the various levels of logging that a message may be tagged with. This allows hiding and
/// showing different logging levels at run time depending on the environment
enum LogLevel: String {
    /// Logging displays nothing
    case None
    
    /// Logging displays *all* logs and additional debug information that may be useful to a developer
    case Debug
    
    /// Logging displays *all* logs (**except** debug)
    case Info
    
    /// Logging displays *only* warnings and above
    case Warning
    
    /// Logging displays *only* errors and above
    case Error
}
