//
//  ViewController+Socket.swift
//  Farsight
//
//  Created by Abdalwahab on 5/15/21.
//

import UIKit
import SwiftyJSON
import Starscream


extension ViewController: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected(let headers):
            isConnected = true
            print("websocket is connected: \(headers)")
            
            // send auth
            let data = [
                "action": "auth",
                "phone_id": Global.phoneID
            ]
            self.send(data, onSuccess: nil)
        case .disconnected(let reason, let code):
            isConnected = false
            print("websocket is disconnected: \(reason) with code: \(code)")
        case .text(let string):
            //                receive(message: self.convertToDictionary(text: string)!)
            receive(message: JSON(string.data(using: .utf8)))
        case .binary(let data):
            print("Received data: \(data.count)")
        case .ping(_):
            break
        case .pong(_):
            break
        case .viabilityChanged(_):
            break
        case .reconnectSuggested(_):
            break
        case .cancelled:
            isConnected = false
        case .error(let error):
            isConnected = false
            print(error.publisher)
        // TODO handle error
        }
    }
    
    func receive(message: JSON) {
                
        switch message["event"].stringValue {
        case "parking_spots":
            print("got parking spots")
            // TODO get spots from here
            // print(message["data"])
        
        case "parking_spot_changed":
            print("spot changed \(message["data"])")
            spotChangedHandle(message: message)
            
        case "street_updated":
            print("street updated \(message["data"])")
            streetChangedHandle(streetID: String(message["data"]["id"].intValue), newCarCount: message["data"]["num_cars"].intValue)
            
        default:
            break
        }
        
    }
    
    func send(_ value: Any, onSuccess: (()-> Void)?) {
        
        guard JSONSerialization.isValidJSONObject(value) else {
            print("[WEBSOCKET] Value is not a valid JSON object.\n \(value)")
            return
        }
        
        print("sending socket message")
        
        do {
            let data = try JSONSerialization.data(withJSONObject: value, options: [])
            print(String(decoding: data, as: UTF8.self))
            socket.write(string: String(decoding: data, as: UTF8.self)) {
                onSuccess?()
            }
        } catch let error {
            print("[WEBSOCKET] Error serializing JSON:\n\(error)")
        }
    }
    
    func spotChangedHandle(message: JSON) {
        // Check if the taken parking spot is mine or not.
        //  If yes, then check phone, if same, ignore, otherwise re-route
        //  Also, change parking spot status.
        guard let spotID = message["data"]["id"].int, let isOccupied = message["data"]["occupied"].bool else {
            return
        }
        
        if isOccupied {
            // check if it is our spot, if any
            if Global.TestingMode {
                testingSpotTaken(phone_id: message["data"]["phone_id"].stringValue, spotID: spotID)
            }else{
                if let route = currentRoute, route.parkingSpotID == spotID {
                    if message["data"]["phone_id"].stringValue != Global.phoneID {
                        // taken spot is our spot and its someone else who took it
                        print("my spot has been taken")
                        
                        if let vc = activeSheet?.childViewController as? RouteViewController {
                            vc.spotTaken()
                        }else{
                            // TODO what if the spot is taken while we are rating?
                        }
                        
                    }else{
                        // ignore since we took our spot
                    }
                }else{
                    // mark spot as taken
                    self.markSpot(taken: true, spotID: spotID)
                }
            }
            
        }else{
            // mark spot empty
            self.markSpot(taken: false, spotID: spotID)
        }
    }
    
}
