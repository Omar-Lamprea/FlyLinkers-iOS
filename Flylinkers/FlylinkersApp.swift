//
//  FlylinkersApp.swift
//  Flylinkers
//
//  Created by Omar Lamprea on 13/05/22.
//

import SwiftUI
import Firebase
//import FirebaseAuth
import GoogleSignIn


@main
struct FlylinkersApp: App {
    
    //Conecting App delegate firebase...
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}



class AppDelegate: NSObject, UIApplicationDelegate {

  //var window: UIWindow?

  func application(_ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions:
    [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
      
      //init firebase...
      FirebaseApp.configure()

    return true
  }
    
    func application(_ application: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any])
      -> Bool {
      return GIDSignIn.sharedInstance.handle(url)
    }
    
}

