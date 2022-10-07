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
import AuthenticationServices
import CryptoKit

var urlApp = "https://app.flylinkers.com/"
//var urlApp = "http://192.168.0.17:3000" //login
//var urlApp = "http://192.168.0.17:8080" //social




struct ContentView: View {
  let webView = WebView(request: URLRequest(url: URL(string: urlApp)!))
  @State var isActive:Bool = false

  var body: some View {
      VStack (){
        if self.isActive {
            webView
            HStack (spacing:0) {
              Button(action: {
                  self.webView.goBack()
              }){
                Image(systemName: "arrowtriangle.left.fill")
                  .font(.title)
                  .foregroundColor(.init(red: 0.09, green: 0.6, blue: 0.67))
                  .padding(.horizontal, 10)
              }
              Spacer()
              Button(action: {
                  self.webView.refresh()
              }){
                Image(systemName: "arrow.clockwise.circle.fill")
                  .font(.title)
                  .foregroundColor(.init(red: 0.09, green: 0.6, blue: 0.67))
                  .padding(.horizontal, 10)
//                  Spacer()
              }
              Spacer()
              Button(action: {
                self.webView.goForward()
              }){
                Image(systemName: "arrowtriangle.right.fill")
                  .font(.title)
                  .foregroundColor(.init(red: 0.09, green: 0.6, blue: 0.67))
                  .padding(.horizontal, 10)
              }
            }
            .background(Color(red: 0.98, green: 0.98, blue: 0.98))
            .border(Color(red: 0.98, green: 0.98, blue: 0.98))
            .padding(.top, -8)
        } else {
            Image("flylinkers-logo")
                .resizable()
                .scaledToFit()
                .background(Color(red: 1, green: 1, blue: 1))
        }
    }
    .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation{
                self.isActive = true
            }
        }
    }
    .background(Color(red: 0.09, green: 0.6, blue: 0.67))
  }
}

struct WebView: UIViewRepresentable {
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding{
        
        
        
        
        var webView: WKWebView?
        fileprivate var currentNonce: String?
        
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            self.webView = webView
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            let btn = message.body
            
            if (btn as! String == "btnGoogle" ) {
                handleGoogleLogin()
            }else if (btn as! String == "btnApple"){
                handleAppeLogin()
            }else{
                let link = URL(string:btn as! String)!
                let request = URLRequest(url: link)
                self.webView?.load(request)
            }
        }

        func messageToWebview(msg: String){
            self.webView?.evaluateJavaScript("webkit.messageHandlers.bridge.onMessage('\(msg)')")
        }
        
        
        private func randomNonceString(length: Int = 32) -> String {
            precondition(length > 0)
            let charset: Array<Character> =
                Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
            var result = ""
            var remainingLength = length
            
            while remainingLength > 0 {
                let randoms: [UInt8] = (0 ..< 16).map { _ in
                    var random: UInt8 = 0
                    let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                    if errorCode != errSecSuccess {
                        fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                    }
                    return random
                }
                
                randoms.forEach { random in
                    if remainingLength == 0 {
                        return
                    }
                    
                    if random < charset.count {
                        result.append(charset[Int(random)])
                        remainingLength -= 1
                    }
                }
            }
            return result
        }

        private func sha256(_ input: String) -> String {
            let inputData = Data(input.utf8)
            let hashedData = SHA256.hash(data: inputData)
            let hashString = hashedData.compactMap {
                return String(format: "%02x", $0)
            }.joined()
            return hashString
        }
        func handleAppeLogin(){
            print("init Apple firebase...")
            
            let nonce = randomNonceString()
            currentNonce = nonce
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
            
            print("lanzando logIn")
        }
        
        
        
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let nonce = currentNonce else {
                    fatalError("Invalid state: A login callback was received, but no login request was sent.")
                }
                guard let appleIDToken = appleIDCredential.identityToken else {
                    print("Unable to fetch identity token")
                    return
                }
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                    return
                }
                let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                          idToken: idTokenString,
                                                          rawNonce: nonce)
                
                Auth.auth().signIn(with: credential) { (authResult, error) in
                    if (error != nil) {
                        print(error?.localizedDescription ?? "")
                        return
                    }
                    guard let user = authResult?.user else { return }
                    let email = user.email ?? ""
                    let displayName = user.displayName ?? ""
                    let uid = String(user.providerData[0].uid)
                    let TK = credential.idToken
                    let userData = [
                        "email": email,
                        "name" : displayName,
                        "uid": uid,
                        "token": TK,
                    ]
                    
                    guard let jsonData = try? JSONSerialization.data(withJSONObject: userData, options: []) else {
                        return
                    }
                    let jsonString = String(data: jsonData, encoding: String.Encoding.utf8)!
                    self.webView?.evaluateJavaScript("getDataFromSwift(\(jsonString))") { result, error in
                        guard error == nil else {
                            print(error as Any)
                            return
                        }
                    }
                    
                }
            }
        }
        
        

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Handle error.
          print("Sign in with Apple errored: \(error)")
          print(error.localizedDescription)
          self.webView?.reload()
        }
        
        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            print("anchor?")
            return ASPresentationAnchor()
        }
        
        
        
        
        func handleGoogleLogin(){
            print("init google firebase...")
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

              guard let authentication = user?.authentication,
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

//                    print(String(user.providerData[0].uid))
                    
                    //post request
                    let Url = String(format: "https://api.flylinkers.com/user/loginapp/")
                    
//                    guard let serviceUrl = URL(string: Url) else { return }
//
//                    let parameters: [String: Any] = [
//                        "request": [
//                            "email": user.email ?? "email",
//                            "password": String(user.providerData[0].uid),
//                            "name": user.displayName ?? "name",
//                            "photo": "\(user.photoURL!)"
//                        ]
//                    ]
                    let pass = user.uid + (user.email ?? "email")
                    let userData: [String: Any] = [
                        "email": user.email ?? "email",
                        "uid": pass,
                        "name": user.displayName ?? "name",
                        "photo": "\(user.photoURL!)",
                        "token" : idToken
                    ]
                    
                    
                    guard let jsonData = try? JSONSerialization.data(withJSONObject: userData, options: []) else {
                        return
                    }
                    let jsonString = String(data: jsonData, encoding: String.Encoding.utf8)!
                    self.webView?.evaluateJavaScript("getDataFromSwift(\(jsonString))") { result, error in
                        guard error == nil else {
                            print(error as Any)
                            return
                        }
                    }

                    
//                    var request = URLRequest(url: serviceUrl)
//                    request.httpMethod = "POST"
//                    request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
//
//                    guard let httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: []) else {
//                        return
//                    }
//                    request.httpBody = httpBody
//                    request.timeoutInterval = 20
//                    let session = URLSession.shared
//                    session.dataTask(with: request) { (data, response, error) in
////                            if let response = response {
////                                //print(response)
////                            }
//                        if let data = data {
//                            do {
//                                let json = try JSONSerialization.jsonObject(with: data, options: [])  as? [String: Any]
////                                    print(json)
//
//                                let created = json!["created"]!
//                                let tk = json!["Detail"]!
//
////                                  print (json!["Detail"]!)
////                                  print (json!["created"]!)
//
//                                var link = URL(string:"https://app.flylinkers.com/?user=\(tk)")!
//
//                                if (created as! Int == 1){
//                                    link = URL(string:"https://app.flylinkers.com/?user=\(tk)&newUser=true")!
//                                }
//
//
//                                let request = URLRequest(url: link)
//                                self.webView?.load(request)
//
//
//                            } catch {
//                                print(error)
//                            }
//                        }
//                    }.resume()
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
        
        webView?.allowsBackForwardNavigationGestures = true
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
