//
//  AppDelegate.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 6/5/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import UIKit
import Mixpanel

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

        Mixpanel.initialize(token: "3d5965256713f8dbf078fbe27605eb76")
        Mixpanel.mainInstance().loggingEnabled = true
        Mixpanel.mainInstance().flushInterval = 20
        Mixpanel.mainInstance().registerSuperProperties(["Plan": "Premium"])
        Mixpanel.removeInstance(name: "lol")
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Mixpanel.mainInstance().time(event: "session length")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        Mixpanel.mainInstance().track(event: "session length")
    }


}
