//
//  Mixpanel.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 6/1/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation


@discardableResult
public func initWithToken(_ apiToken: String,
                          launchOptions: [NSObject: AnyObject]? = nil,
                          flushInterval: Double = 60,
                          instanceName: String = UUID().uuidString) -> MixpanelInstance {
    return MixpanelManager.sharedInstance.initWithToken(apiToken,
                                                        launchOptions: launchOptions,
                                                        flushInterval: flushInterval,
                                                        instanceName: instanceName)
}

public func getInstanceWithName(_ instanceName: String) -> MixpanelInstance? {
    return MixpanelManager.sharedInstance.getInstanceWithName(instanceName)
}

public func mainInstance() -> MixpanelInstance {
    return MixpanelManager.sharedInstance.getMainInstance()!
}

func setMainInstance(newMainInstance: MixpanelInstance) {
    MixpanelManager.sharedInstance.setMainInstance(newMainInstance: newMainInstance)
}

class MixpanelManager {
    static let sharedInstance = MixpanelManager()
    private var instances: [String: MixpanelInstance]
    private var mainInstance: MixpanelInstance?

    init() {
        instances = [String: MixpanelInstance]()
    }

    func initWithToken(_ apiToken: String,
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

    func getInstanceWithName(_ instanceName: String) -> MixpanelInstance? {
        guard let instance = instances[instanceName] else {
            print("no such instance")
            return nil
        }
        return instance
    }

    func getMainInstance() -> MixpanelInstance? {
        return mainInstance
    }

    func setMainInstance(newMainInstance: MixpanelInstance) {
        mainInstance = newMainInstance
    }

}
