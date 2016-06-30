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
        Mixpanel.mainInstance().identify("13792")
        Mixpanel.mainInstance().people.setOnce(["$name":"Joe",
                                                "$email":"joe.bloggs@mixpanel.com"])
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func trackAction(_ sender: AnyObject) {
        Mixpanel.mainInstance().track("press button")
    }

    @IBAction func setPeopleAction(_ sender: AnyObject) {
        Mixpanel.mainInstance().people.set(["weapon":"axe"])
    }
    @IBAction func signupAction(_ sender: AnyObject) {
        Mixpanel.mainInstance().createAlias("13792", distinctId: Mixpanel.mainInstance().distinctId)
        Mixpanel.mainInstance().identify(Mixpanel.mainInstance().distinctId)
    }
}
