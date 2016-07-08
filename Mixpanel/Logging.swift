//
//  Logging.swift
//  MPLogger
//
//  Created by Sam Green on 7/8/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

/// Any object that conforms to this protocol may log messages
protocol Logging {
    func addMessage(message: LogMessage)
}
