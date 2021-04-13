//
//  ImageHook.swift
//  Construction
//
//  Created by Forat Bahrani on 4/8/20.
//  Copyright © 2020 Forat Bahrani. All rights reserved.
//

import Foundation
import Alamofire
import AlamofireImage

protocol ImageHook {
    func onHookStart()
    func onHookEnd()
    func onHookSucceed(image: UIImage, url: URL)
    func onHookFailed(response: AFIDataResponse<AlamofireImage.Image>, message: String)
    func request(_ url: URL, progress: ImageDownloader.ProgressHandler?)
}

extension ImageHook {

    func onHookStart() { }
    func onHookEnd() { }

    func request(_ url: URL, progress: ImageDownloader.ProgressHandler?) {
        onHookStart()

        let urlRequest = URLRequest(url: url)

        Global.imageDownloader.download(urlRequest, progress: progress) { response in
            
            self.onHookEnd()
            if case .success(let image) = response.result {
                self.onHookSucceed(image: image, url: url)
            } else {
//                self.onHookFailed(response: response, message: response.error?.localizedDescription ?? "network_err_default_text".localized)
                self.onHookFailed(response: response, message: "Failed to download image")
            }
        }
    }

}

