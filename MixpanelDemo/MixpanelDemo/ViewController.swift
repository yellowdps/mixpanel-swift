//
//  ViewController.swift
//  MixpanelDemo
//
//  Created by Yarden Eitan on 6/5/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import UIKit
import Mixpanel

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        Mixpanel.mainInstance().identify(distinctId: "13792")
        Mixpanel.mainInstance().people.setOnce(properties: ["$name": "Joe",
                                                "$email": "joe.bloggs@mixpanel.com"])
    }

    @IBAction func trackAction(_ sender: AnyObject) {
        Mixpanel.mainInstance().track(event: "pressed button")
    }

    @IBAction func setPeopleAction(_ sender: AnyObject) {
        Mixpanel.mainInstance().people.set(properties: ["weapon": "axe"])
    }
    @IBAction func signupAction(_ sender: AnyObject) {
        Mixpanel.mainInstance().createAlias("13792", distinctId: Mixpanel.mainInstance().distinctId)
        Mixpanel.mainInstance().identify(distinctId: Mixpanel.mainInstance().distinctId)
    }
}
