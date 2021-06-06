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

/// Use to make requests that utilize token handling mechanism and have response in a closure instead of as a method as in `Hook`. Check for the request
/// status by checking if the `error` property of the `AFDataResponse` object is nil or not.
/// Following the convention followed in `Hook`, `rawResponse` is only added to the `completionHandler` for errors. Otherwise, it is nil.
/// Same goes for `errorMessage`.
/// Named `requestImmediate` so that it won't be called by mistake instead of `Hook.request`
func requestImmediate(_ endpoint: String,
             params: Parameters? = nil,
             method: HTTPMethod = .get,
             encoding: ParameterEncoding = URLEncoding.default,
             completionHandler: ((_ successResult: JSON?, _ rawResponse: AFDataResponse<Data?>?, _ errorMessage: String?) -> Void)? = nil)
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
        completionHandler?(nil, defaultResponse, "you are not connected to the internet")
        return
    }

    let url = Global.base_url + endpoint
    #if DEBUG
        print(url)
    #endif
    var headers: HTTPHeaders? = nil

    let request = AF.request(url, method: method, parameters: params, encoding: encoding, headers: headers)

    func handleResult(result: AFDataResponse<Data?>) {
        if result.response!.statusCode < 300 {
            let value = result.value ?? JSON()
            let json = JSON(value)
            completionHandler?(json, nil, nil)
        } else {
            print(String(decoding: result.value!!, as: UTF8.self))
            completionHandler?(nil, result, "you are not connected to the internet")
        }
    }

    request.response { (result) in
        handleResult(result: result)
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
