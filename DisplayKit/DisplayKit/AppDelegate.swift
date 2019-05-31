//
//  AppDelegate.swift
//  ExampleOpenBids
//
//  Created by Yaroslav Skachkov on 10/16/18.
//  Copyright © 2018 Yaroslav Skachkov. All rights reserved.
//

import UIKit
import BidMachine


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }
}

extension AppDelegate: BDMAdEventProducerDelegate  {
    func didProduceImpression(_ producer: BDMAdEventProducer) {
        __print("BDMAdEventProducerDelegate")
    }
    
    func didProduceUserAction(_ producer: BDMAdEventProducer) {
        __print("BDMAdEventProducerDelegate")

    }
}

extension UIApplication {
    var mainStoryboard: UIStoryboard {
        get {
            return UIStoryboard(name: "Main", bundle: nil)
        }
    }
    
    var cornerCasesStoryboard:UIStoryboard {
        get {
            return UIStoryboard(name: "CornerCases", bundle: nil)
        }
    }
}

extension UIStoryboard {
    func instantiateVC<T: UIViewController>() -> T? {
        let name = String(describing: T.self)
        return instantiateViewController(withIdentifier: name) as? T 
    }
}