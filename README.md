[![Build Status](https://travis-ci.org/mixpanel/mixpanel-swift-private.svg?branch=yolo-travis-ci)](https://travis-ci.org/mixpanel/mixpanel-swift-private)
[![Average time to resolve an issue](http://isitmaintained.com/badge/resolution/mixpanel/mixpanel-swift-private.svg)](http://isitmaintained.com/project/mixpanel/mixpanel-swift-private "Average time to resolve an issue")
[![Percentage of issues still open](http://isitmaintained.com/badge/open/mixpanel/mixpanel-swift-private.svg)](http://isitmaintained.com/project/mixpanel/mixpanel-swift-private "Percentage of issues still open")
[![CocoaPods Version](http://img.shields.io/cocoapods/v/Mixpanel.svg?style=flat)](https://mixpanel.com)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Apache License](http://img.shields.io/cocoapods/l/Mixpanel.svg?style=flat)](https://mixpanel.com)

**Want to Contribute?**

The Mixpanel Swift library for iOS is an open source project, and we'd love to see your contributions! We'd also love for you to come and work with us! Check out http://boards.greenhouse.io/mixpanel/jobs/25226#.U_4JXEhORKU for details.

# Painless Installation (CocoaPods)

Mixpanel supports `CocoaPods` for easy installation.
To Install, see our **[full documentation »](https://mixpanel.com/help/reference/swift)**

`pod 'Mixpanel-swift'`

# Carthage

Mixpanel also supports `Carthage` to package your dependencies as a framework.
Check out the **[Carthage docs »](https://github.com/Carthage/Carthage)** for more info.

# Manual Installation

To help users stay up to date with the latests version of our iOS SDK, we always recommend integrating our SDK via CocoaPods, which simplifies version updates and dependency management. However, there are cases where users can't use CocoaPods. Not to worry, just follow these manual installation steps and you'll be all set.

##Step 1: Add as a Submodule

...

##Step 2: Drag Mixpanel to your project

...

##Step 3: Embed the framework

...

## Step 4: Integrate!

Import Mixpanel into AppDelegate.swift, and initialize Mixpanel within `application:didFinishLaunchingWithOptions:`


```
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    Mixpanel.initialize(token: MIXPANEL_TOKEN)
}
```

## Start tracking

You're done! You've successfully integrated the Mixpanel SDK into your app. To stay up to speed on important SDK releases and updates, star or watch our repository on [Github](https://github.com/mixpanel/mixpanel-swift-private).

Have any questions? Reach out to [support@mixpanel.com](mailto:support@mixpanel.com) to speak to someone smart, quickly.
