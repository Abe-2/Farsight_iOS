//
//  Hook.swift
//  Construction
//
//  Created by Forat Bahrani on 3/15/20.
//  Copyright © 2020 Forat Bahrani. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON
import Starscream

// TODO enable localization to group all strings in one file
/*
protocol Hook {
    func onHookStart(uid: String)
    func onHookEnd(uid: String)
    func onHookSucceed(payload: JSON, uid: String)
    func onHookFailed(result: AFDataResponse<Data?>, message: String, uid: String)
    func request(_ endpoint: String, params: Parameters?, method: HTTPMethod, encoding: ParameterEncoding, requiresToken: Bool, uid: String, loadFromCache: Bool, useAlertLoading: Bool)
    
    // TODO add uid for setupLoadingAlert to allow for multiple loading styles for multiple requests in the same vc
    /// must be called if `useAlertLoading` in `request` method was set to true. Else, a fatal error will be thrown. The implementation must initialize the loading alert controller and also present it.  The alert will be dismissed automatically when the request resolves
    /// - Author: Abe
    func setupLoadingAlert() -> UIAlertController
}

protocol UploadHook: Hook {
    func upload(_ endpoint: String, params: Parameters?, files: [Data: String], filesKeyName: String, method: HTTPMethod, requiresToken: Bool, uid: String)
    func uploadProgressChanged(progress: Progress, uid: String)
}

var messagesChanged = false
var HookCaches: [String: JSON] = [:]

extension Hook {

    func onHookStart(uid: String) { }
    func onHookEnd(uid: String) { }
    
    func setupLoadingAlert() -> UIAlertController {
        fatalError("the loading alert was not setup. Implement setupLoadingAlert from Hook protocol")
    }

    // WARNING: the caching method can potinetially cause issues from cross account content. For example, when I logout, the cached data stays in the app
    // for another potential user (assuming multiple users on same device) to retrieve that data even if they don't have access to
    func request(_ endpoint: String,
                 params: Parameters? = nil,
                 method: HTTPMethod = .get,
                 encoding: ParameterEncoding = URLEncoding.default,
                 requiresToken: Bool = true,
                 uid: String = String.random(),
                 loadFromCache: Bool = false,
                 useAlertLoading: Bool = false)
    {
        onHookStart(uid: uid)
        
        var loadingAlert: UIAlertController? = nil
        if useAlertLoading {
            loadingAlert = setupLoadingAlert()
            
        }

        // used for manual cancellation of request
        let defaultResponse = AFDataResponse<Data?>(
            request: nil,
            response: nil,
            data: nil,
            metrics: nil,
            serializationDuration: 0,
            result: .failure(AFError.explicitlyCancelled)
        )

        guard Reachability.isConnectedToNetwork() else {
            self.onHookEnd(uid: uid)
//            self.onHookFailed(result: defaultResponse, message: "network_err_default_text".localized, uid: uid)
            callHookFailed(result: defaultResponse, message: "network_err_default_text".localized, uid: uid, useAlertLoading: useAlertLoading, alert: loadingAlert)
            return
        }

        TokenHandler.handle(requiresToken: requiresToken) { (succeed) in

            guard succeed else {
                
                let completion = {
                    self.onHookEnd(uid: uid)
                    global.accessToken = nil
                    global.refreshToken = nil
                }
                
                if useAlertLoading {
                    loadingAlert?.dismiss(animated: true) {
                        completion()
                    }
                }else{
                    completion()
                }
                
                return
            }

            let url = endpoint.starts(with: "http") ? endpoint : global.base_url + endpoint
            #if DEBUG
                print(url)
            #endif
            var headers: HTTPHeaders? = nil
            if requiresToken, let access = global.accessToken { headers = ["Authorization": "Bearer \(access)"] } else {
                #if DEBUG
                    print("No authorization")
                #endif
            }

            let request = AF.request(url, method: method, parameters: params, encoding: encoding, headers: headers)

            let cache = "\(url)--\(String(describing: params))--\(method)--\(encoding)--\(String(describing: headers))"

            if loadFromCache, let cachedPayload = HookCaches[cache] {

                // TODO why does chat get special treatment?
                let mustCall = url.contains("/chat/") && messagesChanged
                if !mustCall {
                    print("loading \(endpoint) from cache")
                    self.onHookEnd(uid: uid)
//                    self.onHookSucceed(payload: cachedPayload, uid: uid)
                    callHookSucceed(payload: cachedPayload, uid: uid, useAlertLoading: useAlertLoading, alert: loadingAlert)
                    return
                } else {
                    messagesChanged = false
                }

            }

            func handleResult(result: AFDataResponse<Data?>) {
                HookCaches[cache] = nil
                self.onHookEnd(uid: uid)
                print(result.result)
                if let optValue = result.value,
                   let value = optValue {
                    let json = JSON(value)
                    if json["status"] == "ok" {
                        HookCaches[cache] = json["payload"]
                        self.callHookSucceed(payload: json["payload"], uid: uid, useAlertLoading: useAlertLoading, alert: loadingAlert)
                    } else {
                        self.callHookFailed(result: result, message: json["message"].string ?? "network_err_default_text".localized, uid: uid, useAlertLoading: useAlertLoading, alert: loadingAlert)
                    }
                } else {
                    self.callHookFailed(result: result, message: "network_err_default_text".localized, uid: uid, useAlertLoading: useAlertLoading, alert: loadingAlert)
                }
            }

            request.response { (result) in
                handleResult(result: result)
            }

        }
    }
    
    /// This method basically calls the onHookSucceed but with support for the alert loading logic to avoid repeatition.
    fileprivate func callHookSucceed(payload: JSON, uid: String, useAlertLoading: Bool = false, alert: UIAlertController? = nil) {
        if useAlertLoading {
            assert(alert != nil)
            alert?.dismiss(animated: true, completion: {
                self.onHookSucceed(payload: payload, uid: uid)
            })
        }else{
            self.onHookSucceed(payload: payload, uid: uid)
        }
    }
    
    fileprivate func callHookFailed(result: AFDataResponse<Data?>, message: String, uid: String, useAlertLoading: Bool = false, alert: UIAlertController? = nil) {
        if useAlertLoading {
            assert(alert != nil)
            alert?.dismiss(animated: true, completion: {
                self.onHookFailed(result: result, message: message, uid: uid)
            })
        }else{
            self.onHookFailed(result: result, message: message, uid: uid)
        }
    }

}
*/

extension UIViewController {
    
    /// Use to make requests that utilize token handling mechanism and have response in a closure instead of as a method as in `Hook`. Check for the request
    /// status by checking if the `error` property of the `AFDataResponse` object is nil or not.
    /// Following the convention followed in `Hook`, `rawResponse` is only added to the `completionHandler` for errors. Otherwise, it is nil.
    /// Same goes for `errorMessage`.
    /// Named `requestImmediate` so that it won't be called by mistake instead of `Hook.request`
    func requestImmediate(_ endpoint: String,
                 params: Parameters? = nil,
                 method: HTTPMethod = .get,
                 encoding: ParameterEncoding = URLEncoding.default,
//                 requiresToken: Bool = true,
//                 loadFromCache: Bool = false,
                 completionHandler: @escaping (_ successResult: JSON?, _ rawResponse: AFDataResponse<Data?>?, _ errorMessage: String?) -> Void)
    {

        // used for manual cancellation of request
        let defaultResponse = AFDataResponse<Data?>(
            request: nil,
            response: nil,
            data: nil,
            metrics: nil,
            serializationDuration: 0,
            result: .failure(AFError.explicitlyCancelled)
        )

        guard Reachability.isConnectedToNetwork() else {
//            completionHandler(nil, defaultResponse, "network_err_default_text".localized)
            completionHandler(nil, defaultResponse, "you are not connected to the internet")
            return
        }

        let url = Global.base_url + endpoint
        #if DEBUG
            print(url)
        #endif
        var headers: HTTPHeaders? = nil
//        if requiresToken, let access = global.accessToken { headers = ["Authorization": "Bearer \(access)"] } else {
//            #if DEBUG
//                print("No authorization")
//            #endif
//        }

        let request = AF.request(url, method: method, parameters: params, encoding: encoding, headers: headers)

//        let cache = "\(url)--\(String(describing: params))--\(method)--\(encoding)--\(String(describing: headers))"

//        if loadFromCache, let cachedPayload = HookCaches[cache] {
//            print("loading \(endpoint) from cache")
//            completionHandler(cachedPayload, nil, "")
//            return
//        }

        func handleResult(result: AFDataResponse<Data?>) {
//            HookCaches[cache] = nil
            if result.response!.statusCode < 300 {
                let value = result.value ?? JSON()
                let json = JSON(value)
                completionHandler(json, nil, nil)
            } else {
                print(String(decoding: result.value!!, as: UTF8.self))
//                completionHandler(nil, result, "network_err_default_text".localized)
                completionHandler(nil, result, "you are not connected to the internet")
            }
        }

        request.response { (result) in
            handleResult(result: result)
        }
    }
    
}

extension WebSocketDelegate {
    func connect() -> WebSocket {
        print("connecting to \(Global.base_ws)")
        var request = URLRequest(url: URL(string: Global.base_ws)!)
        request.timeoutInterval = 10
        let socket = WebSocket(request: request)
        socket.delegate = self
        socket.connect()
        return socket
    }
    
    func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil  // TODO better to throw error
    }
}
