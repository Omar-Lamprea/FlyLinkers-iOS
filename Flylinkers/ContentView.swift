////
////  ContentView.swift
////  Flylinkers
////
////  Created by Omar Lamprea on 13/05/22.
////
//

import SwiftUI
import WebKit
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

import Foundation


//self.webView?.allowsBackForwardNavigationGestures

var urlApp = "https://app.flylinkers.com/"

struct ContentView: View {
  let webView = WebView(request: URLRequest(url: URL(string: urlApp)!))
  var body: some View {
    VStack {
      webView
    
      HStack {
        Button(action: {
            self.webView.goBack()
        }){
          Image(systemName: "arrowtriangle.left.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                            .padding()
        }
        Spacer()
        Button(action: {
            self.webView.refresh()
        }){
          Image(systemName: "arrow.clockwise.circle.fill")
                .font(.title)
                .foregroundColor(.blue)
                .padding()
        }
        Spacer()
        Button(action: {
          self.webView.goForward()
        }){
          Image(systemName: "arrowtriangle.right.fill")
                .font(.title)
                .foregroundColor(.blue)
                .padding()
        }
      }
    }
  }
}


struct WebView: UIViewRepresentable {
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler{

        var webView: WKWebView?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            self.webView = webView
        }


        func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage) {
            //print("holaaaaaaa", message.body)

            handleGoogleLogin()

        }

        func messageToWebview(msg: String){
            self.webView?.evaluateJavaScript("webkit.messageHandlers.bridge.onMessage('\(msg)')")
        }

        func handleGoogleLogin(){
            print("hola firebase =)")
            
            guard let clientID = FirebaseApp.app()?.options.clientID else { return }

            // Create Google Sign In configuration object.
            let config = GIDConfiguration(clientID: clientID)

            GIDSignIn.sharedInstance.signIn(with: config, presenting: getRootViewController()) {
                [self] user, error in

              if let error = error {
                  webView?.reload()
                  print(error.localizedDescription)
                return
              }

              guard
                let authentication = user?.authentication,
                let idToken = authentication.idToken
              else {
                return
              }

              let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: authentication.accessToken)


                Auth.auth().signIn(with: credential){ result, error in

                    if let error = error{
                        
                        print(error.localizedDescription)
                        return
                    }

                    guard let user = result?.user  else{
                        return
                    }

                    print(String(user.providerData[0].uid))
                    
                    let Url = String(format: "https://api.flylinkers.com/user/loginapp/")
                        guard let serviceUrl = URL(string: Url) else { return }
                        let parameters: [String: Any] = [
                            "request": [
                                "email": user.email ?? "email",
                                "password": String(user.providerData[0].uid),
                                "name": user.displayName ?? "name",
                                "photo": "\(user.photoURL!)"
                            ]
                        ]
                        var request = URLRequest(url: serviceUrl)
                        request.httpMethod = "POST"
                        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
                        guard let httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: []) else {
                            return
                        }
                        request.httpBody = httpBody
                        request.timeoutInterval = 20
                        let session = URLSession.shared
                        session.dataTask(with: request) { (data, response, error) in
//                            if let response = response {
//                                //print(response)
//                            }
                            if let data = data {
                                do {
                                    let json = try JSONSerialization.jsonObject(with: data, options: [])  as? [String: Any]
//                                    print(json)

                                    let created = json!["created"]!
                                    let tk = json!["Detail"]!
                                    
//                                  print (json!["Detail"]!)
//                                  print (json!["created"]!)
                                    
                                    var link = URL(string:"https://app.flylinkers.com/?user=\(tk)")!
                                    
                                    if (created as! Int == 1){
                                        link = URL(string:"https://app.flylinkers.com/?user=\(tk)&newUser=true")!
                                    }
                                    
                                    
                                    let request = URLRequest(url: link)
                                    self.webView?.load(request)
                                    
                                    
                                } catch {
                                    print(error)
                                }
                            }
                        }.resume()

                    
                    
                }
            }
        }


        func getRect()->CGRect{
            return UIScreen.main.bounds
        }

        func getRootViewController()->UIViewController{
            guard let screen = UIApplication.shared.connectedScenes.first as? UIWindowScene else{
                return .init()
            }

            guard let root = screen.windows.first?.rootViewController else{
                return .init()
            }

            return root
        }

//        func sendFirebaseAuthWithGoogle(username: String){
//            let user = "Soy el Usuario: " + username
//            print(user)
//        }
    }




    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    let request: URLRequest
    private var webView: WKWebView?
    
    init(request: URLRequest) {
        self.webView = WKWebView()
        self.request = request
    }
  
    func makeUIView(context: Context) -> WKWebView {
        let coordinator = makeCoordinator()
        
        webView?.configuration.userContentController.add(coordinator, name: "bridge")
        webView?.navigationDelegate = coordinator
        
        return webView!
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.load(request)
    }
    
    func goBack(){
        webView?.goBack()
    }

    func goForward(){
        webView?.goForward()
    }
    
    func refresh() {
        webView?.reload()
    }
    
    func goHome() {
        webView?.load(request)
    }
    
    
}



//import UIKit
//import WebKit
//
//class ViewController: UIViewController, WKNavigationDelegate{
//
//    var webView: WKWebView!
//
//    override func loadView() {
//        webView = WKWebView()
//        webView.navigationDelegate = self
//        view = webView
//    }
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//
//        let url = URL(string: "http://192.168.20.48:3000")!
//        webView.load(URLRequest(url: url))
//        webView.allowsBackForwardNavigationGestures = true
//    }
//}
