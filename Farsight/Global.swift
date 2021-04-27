//
//  Global.swift
//  Farsight
//
//  Created by Abdalwahab on 1/13/21.
//

import Foundation
import AlamofireImage

class Global {
    static let base_url = "https://farsight-api.herokuapp.com/client"
    static let base_ws = "ws://farsight-api.herokuapp.com/ws/parking/"
    static let phoneID = "45"
    
    static let imageDownloader = ImageDownloader(
        configuration: ImageDownloader.defaultURLSessionConfiguration(),
        downloadPrioritization: .fifo,
        maximumActiveDownloads: 2,
        imageCache: AutoPurgingImageCache()
    )
}
