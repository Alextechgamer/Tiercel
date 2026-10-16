//
//  AppDelegate.swift
//  Example
//
//  Created by Daniels on 2018/3/16.
//  Copyright © 2018 Daniels. All rights reserved.
//

import UIKit
import Tiercel
import SwiftUI

let appDelegate = UIApplication.shared.delegate as! AppDelegate

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    lazy var tiercelLabModel = TiercelLabModel()
    
    lazy var sessionManager1 = SessionManager("ViewController1", configuration: SessionConfiguration())
    
    lazy var sessionManager2: SessionManager = {
        var configuration = SessionConfiguration()
        configuration.allowsCellularAccess = true
        let path = Cache.defaultDiskCachePathClosure("Test")
        let cacahe = Cache("ViewController2", downloadPath: path)
        let manager = SessionManager("ViewController2", configuration: configuration, cache: cacahe, operationQueue: DispatchQueue(label: "com.Tiercel.SessionManager.operationQueue"))
        return manager
    }()
    
    lazy var sessionManager3 = SessionManager("ViewController3", configuration: SessionConfiguration())
    
    lazy var sessionManager4 = SessionManager("ViewController4", configuration: SessionConfiguration())

    

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let newWindow = UIWindow(frame: UIScreen.main.bounds)
        newWindow.rootViewController = UIHostingController(rootView: TiercelLabView(model: tiercelLabModel))
        window = newWindow
        newWindow.makeKeyAndVisible()
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.environment["TIERCEL_LAB_AUTORUN"] == "1" {
            DispatchQueue.main.async { [weak self] in self?.tiercelLabModel.start() }
        }
        #endif
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        if tiercelLabModel.manager.identifier == identifier {
            tiercelLabModel.manager.completionHandler = completionHandler
        } else {
            completionHandler()
        }
    }


}

