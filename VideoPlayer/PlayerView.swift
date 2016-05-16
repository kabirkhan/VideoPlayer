//
//  PlayerView.swift
//  StreamingVideo-Demo
//
//  Created by Jack Davis on 2/15/16.
//  Copyright © 2016 Nine-42 LLC. All rights reserved.
//

import UIKit
import AVFoundation

class PlayerView: UIView {

    var mediaPlayerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    var mediaPlayer: AVPlayer? {
        get {
            return mediaPlayerLayer.player
        }
        set {
            mediaPlayerLayer.player = newValue
        }
    }
    
    override class func layerClass() -> AnyClass {
        return AVPlayerLayer.self
    }
}
