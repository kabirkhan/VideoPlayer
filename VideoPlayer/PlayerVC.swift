//
//  PlayerVC.swift
//  StreamingVideo-Demo
//
//  Created by Jack Davis on 2/15/16.
//  Copyright © 2016 Nine-42 LLC. All rights reserved.
//

import UIKit
import AVFoundation

// KVO Context
private var mediaPlayerViewControllerKVOContext = 0

class PlayerVC: UIViewController {
    
    
    //MARK: - IBOutlets
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var startTimeLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var rewindButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var fastforwardButton: UIButton!
    @IBOutlet weak var mediaPlayerView: PlayerView!
    
    
    // MARK: - Properties
    
    // CHANGE THIS URL
    let url = "https://s3-us-west-2.amazonaws.com/demovideosforvideoplayertest/Stephen_Curry_Highlights.mp4"
    
    let player = AVPlayer()
    
    static let keysRequiredToPlay = [
        "playable",
        "hasProtectedContent"
    ]
    
    var currentTime: Double {
        get {
            return CMTimeGetSeconds(player.currentTime())
        }
        set {
            let newTime = CMTimeMakeWithSeconds(newValue, 1)
            player.seekToTime(newTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
        }
    }
    
    var currentTimeAsString: String {
        return formatTimeAsString(currentTime)
    }
    
    var duration: Double {
        if let currentItem = player.currentItem {
            return CMTimeGetSeconds(currentItem.duration)
        } else {
            return 0.0
        }
    }
    
    var timeLeftAsString: String {
        return formatTimeAsString(duration - currentTime)
    }

    var playbackRate: Float {
        get {
            return player.rate
        }
        set {
            player.rate = newValue
        }
    }
    
    var urlAsset: AVURLAsset? {
        didSet {
            if let newAsset = urlAsset {
                asyncLoadURLAsset(newAsset)
            } else {
                return
            }
        }
    }
    
    private var mediaPlayerLayer: AVPlayerLayer? {
        return mediaPlayerView.mediaPlayerLayer
    }
    
    private var timeToken: AnyObject?
    
    private var mediaPlayerItem: AVPlayerItem? = nil {
        didSet {
            player.replaceCurrentItemWithPlayerItem(self.mediaPlayerItem)
        }
    }
    
    
    // MARK: - VC
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        addObserver(self, forKeyPath: "player.currentItem.status", options: [.New, .Initial], context: &mediaPlayerViewControllerKVOContext)
        addObserver(self, forKeyPath: "player.currentItem.duration", options: [.New, .Initial], context: &mediaPlayerViewControllerKVOContext)
        addObserver(self, forKeyPath: "player.rate", options: [.New, .Initial], context: &mediaPlayerViewControllerKVOContext)
        
        mediaPlayerView.mediaPlayerLayer.player = player
       
        guard let lessonURL = NSURL(string: url) else {
            let message = "Error with lessonURL"
            self.showAlert(message)
            return
        }
        
        urlAsset = AVURLAsset(URL: lessonURL, options: nil)

        let interval = CMTimeMake(1, 1)
        timeToken = player.addPeriodicTimeObserverForInterval(interval, queue: dispatch_get_main_queue(), usingBlock: { time in
            self.timeSlider?.value = Float(CMTimeGetSeconds(time))
            self.startTimeLabel.text = self.currentTimeAsString
            self.durationLabel.text = self.timeLeftAsString
        })
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        if let token = timeToken {
            player.removeTimeObserver(token)
            self.timeToken = nil
        }
        
        player.pause()
        
        self.removeObserver(self, forKeyPath: "player.currentItem.status", context: &mediaPlayerViewControllerKVOContext)
        self.removeObserver(self, forKeyPath: "player.currentItem.duration", context: &mediaPlayerViewControllerKVOContext)
        self.removeObserver(self, forKeyPath: "player.rate", context: &mediaPlayerViewControllerKVOContext)
    }
    
    
    // MARK: - Media Loading
    func asyncLoadURLAsset(asset: AVURLAsset) {
        asset.loadValuesAsynchronouslyForKeys(PlayerVC.keysRequiredToPlay) {
            
            dispatch_async(dispatch_get_main_queue()) {
                if asset == self.urlAsset {
                    for key in PlayerVC.keysRequiredToPlay {
                        var error: NSError?
                        
                        if asset.statusOfValueForKey(key, error: &error) == .Failed {
                            let message = "Asset key failed to load"
                            self.showAlert(message, error: error)
                            
                            return
                        }
                    }
                    self.mediaPlayerItem = AVPlayerItem(asset: asset)
                    self.player.play()
                } else {
                    return
                }
            }
        }
    }
    
    
    // MARK: - IBActions
    @IBAction func playPauseButtonTapped(sender: UIButton) {
        if player.rate != 1.0 {
            if currentTime == duration {
                self.currentTime = 0.0
            }
            
            player.play()
        } else {
            player.pause()
        }
    }
    
    @IBAction func rewindButtonTapped(sender: UIButton) {
        playbackRate = max(playbackRate - 2.0, -2.0)
    }
    
    @IBAction func fastForwardButtonTapped(sender: UIButton) {
        playbackRate = min(playbackRate + 2.0, 2.0)
    }
    
    @IBAction func timeSliderValueDidChange(sender: UISlider) {
        currentTime = Double(sender.value)
    }
    
    
    // MARK: - KVO
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        guard context == &mediaPlayerViewControllerKVOContext else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
            return
        }
        
        if keyPath == "player.currentItem.duration" {
            let newDuration: CMTime
            if let newDurationAsValue = change?[NSKeyValueChangeNewKey] as? NSValue {
                newDuration = newDurationAsValue.CMTimeValue
            } else {
                newDuration = kCMTimeZero
            }
            
            let isValidDuration = newDuration.isNumeric && newDuration.value != 0
            let newDurationSecs = isValidDuration ? CMTimeGetSeconds(newDuration) : 0.0
            
            timeSlider.maximumValue = Float(newDurationSecs)
            timeSlider.value = isValidDuration ? Float(CMTimeGetSeconds(player.currentTime())) : 0.0
            rewindButton.enabled = isValidDuration
            playButton.enabled = isValidDuration
            fastforwardButton.enabled = isValidDuration
            timeSlider.enabled = isValidDuration
            startTimeLabel.enabled = isValidDuration
            durationLabel.enabled = isValidDuration
            
            let wholeMinutes = Int(trunc(newDurationSecs / 60))
            durationLabel.text = String(format:"%d:%02d", wholeMinutes, Int(trunc(newDurationSecs)) - wholeMinutes * 60)
            
        } else if keyPath == "player.currentItem.status" {
            let newStatus: AVPlayerItemStatus
            if let newStatusAsValue = change?[NSKeyValueChangeNewKey] as? NSNumber {
                newStatus = AVPlayerItemStatus(rawValue: newStatusAsValue.integerValue)!
            } else {
                newStatus = AVPlayerItemStatus.Unknown
            }
            
            if newStatus == AVPlayerItemStatus.Failed {
                self.showAlert("Error: player failed", error: player.currentItem?.error)
            }
        } else if keyPath == "player.rate" {
            let newRate = (change?[NSKeyValueChangeNewKey] as? NSNumber)?.doubleValue
            let buttonName = newRate == 1.0 ? "stop" : "play"
            let buttonImage = UIImage(named: buttonName)
            playButton.setImage(buttonImage, forState: .Normal)
        }
    }
    
    override class func keyPathsForValuesAffectingValueForKey(key: String) -> Set<String> {
        let affectedKeyPathsMappingByKey: [String: Set<String>] = [
            "duration": ["player.currentItem.duration"],
            "currentTime": ["player.currentItem.currentTime"],
            "rate": ["player.rate"]
        ]
        
        return affectedKeyPathsMappingByKey[key] ?? super.keyPathsForValuesAffectingValueForKey(key)
    }
    
    // MARK: - Helper Functions
    func showAlert(message: String, error: NSError? = nil) {
        var alertMessage: String
        if error != nil {
            alertMessage = "Error occurred with messsage: \(message), error: \(error)"
        } else {
            alertMessage = "Error occurred with messae: \(message)"
        }
        
        let alert = UIAlertController(title: "Error", message: alertMessage, preferredStyle: .Alert)
        let alertAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
        alert.addAction(alertAction)
        self.presentViewController(alert, animated: true, completion: nil)
        
    }
    
    func formatTimeAsString(time: Double) -> String {
        let minutes = Int(trunc(time / 60))
        return String(format:"%d:%02d", minutes, Int(trunc(time)) - minutes * 60)
    }
}
