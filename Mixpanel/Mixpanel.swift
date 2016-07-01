//
//  Mixpanel.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/1/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation


@discardableResult
public func initialize(token apiToken: String,
                       launchOptions: [NSObject: AnyObject]? = nil,
                       flushInterval: Double = 60,
                       instanceName: String = UUID().uuidString) -> MixpanelInstance {
    return MixpanelManager.sharedInstance.initialize(token:         apiToken,
                                                     launchOptions: launchOptions,
                                                     flushInterval: flushInterval,
                                                     instanceName:  instanceName)
}

public func getInstance(name instanceName: String) -> MixpanelInstance? {
    return MixpanelManager.sharedInstance.getInstance(name: instanceName)
}

public func mainInstance() -> MixpanelInstance {
    return MixpanelManager.sharedInstance.getMainInstance()!
}

public func setMainInstance(name instanceName: String) {
    MixpanelManager.sharedInstance.setMainInstance(name: instanceName)
}

public func removeInstance(name instanceName: String) {
    MixpanelManager.sharedInstance.removeInstance(name: instanceName)
}

class MixpanelManager {
    static let sharedInstance = MixpanelManager()
    private var instances: [String: MixpanelInstance]
    private var mainInstance: MixpanelInstance?

    init() {
        instances = [String: MixpanelInstance]()
    }

    func initialize(token apiToken: String,
                    launchOptions: [NSObject: AnyObject]?,
                    flushInterval: Double,
                    instanceName: String) -> MixpanelInstance {
        let instance = MixpanelInstance(apiToken: apiToken,
                                        launchOptions: launchOptions,
                                        flushInterval: flushInterval)
        mainInstance = instance
        instances[instanceName] = instance

        return instance
    }

    func getInstance(name instanceName: String) -> MixpanelInstance? {
        guard let instance = instances[instanceName] else {
            print("no such instance")
            return nil
        }
        return instance
    }

    func getMainInstance() -> MixpanelInstance? {
        return mainInstance
    }

    func setMainInstance(name instanceName: String) {
        guard let instance = instances[instanceName] else {
            return
        }
        mainInstance = instance
    }
    
    func removeInstance(name instanceName: String) {
        instances[instanceName] = nil
    }

}
