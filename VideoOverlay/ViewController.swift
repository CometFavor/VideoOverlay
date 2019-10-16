//
//  ViewController.swift
//  VideoOverlay
//
//  Created by MacMaster on 9/17/19.
//  Copyright © 2019 MacMaster. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit

class ViewController: UIViewController {

    @IBOutlet weak var procceed_btn: UIButton!
    var videoMerger : VideoMerger!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func procceed_btn_clicked(_ sender: UIButton) {
        
        /*guard let url1 = Bundle.main.url(forResource: "back3", withExtension: "MOV") else {
            print("Impossible to find the video.")
            return
        }
        
        guard let url2 = Bundle.main.url(forResource: "front3", withExtension: "MOV") else {
            print("Impossible to find the video.")
            return
        }*/
        
        guard let url1 = Bundle.main.url(forResource: "back-landscape-right", withExtension: "mov") else {
            print("Impossible to find the video.")
            return
        }
        
        
        guard let url2 = Bundle.main.url(forResource: "front-landscape-right", withExtension: "mov") else {
            print("Impossible to find the video.")
            return
        }
        
        let layout_back = DBVideoLayout()
        layout_back.width = 800
        layout_back.height = 450
        
        layout_back.originX = 400
        layout_back.originY = 300
        
        layout_back.reversed = true
        
        let layout_front = DBVideoLayout()
        layout_front.width = 360
        layout_front.height = 360
        
        layout_front.originX = 500
        layout_front.originY = 400
        layout_back.reversed = true
        
        // Export to file
        let dirPaths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        
        let docsURL = dirPaths[0]
        
        let path = docsURL.path.appending("/mergedVideo.mp4")
        let exportURL = URL.init(fileURLWithPath: path)
        
        videoMerger = VideoMerger(url1: url1, url2: url2, layout1: layout_back, layout2: layout_front, export: exportURL, vc: self)
        
        //videoMerger.orientation = VideoMerger.ORI_PORT
        videoMerger.orientation = VideoMerger.ORI_LAND
        procceed_btn.isEnabled = false
        
        videoMerger.startRendering()
    }
    
    func appendAudio(audioURL: URL, videoURL: URL, exportURL: URL) -> Void {
        mergeFilesWithUrl(videoUrl: videoURL, audioUrl: audioURL, savePathUrl: exportURL)
    }
    
    func openPreviewScreen(_ videoURL:URL) -> Void {
        DispatchQueue.main.async {
            self.procceed_btn.isEnabled = true
            
            let player = AVPlayer(url: videoURL)
            let playerController = AVPlayerViewController()
            playerController.player = player
            
            self.present(playerController, animated: true, completion: {
                player.play()
            })
        }
        
    }
    
    func mergeFilesWithUrl(videoUrl:URL, audioUrl:URL, savePathUrl: URL)
    {
        let mixComposition : AVMutableComposition = AVMutableComposition()
        var mutableCompositionVideoTrack : [AVMutableCompositionTrack] = []
        var mutableCompositionAudioTrack : [AVMutableCompositionTrack] = []
        let totalVideoCompositionInstruction : AVMutableVideoCompositionInstruction = AVMutableVideoCompositionInstruction()
        
        //start merge
        
        let aVideoAsset : AVAsset = AVAsset(url: videoUrl)
        let aAudioAsset : AVAsset = AVAsset(url: audioUrl)
        
        let audio_count = aAudioAsset.tracks(withMediaType: AVMediaType.audio).count
        
        mutableCompositionVideoTrack.append(mixComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)!)
        
        if audio_count > 0 {
            mutableCompositionAudioTrack.append( mixComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)!)
        }
        
        let aVideoAssetTrack : AVAssetTrack = aVideoAsset.tracks(withMediaType: AVMediaType.video)[0]
        
        
        do{
            try mutableCompositionVideoTrack[0].insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: aVideoAssetTrack.timeRange.duration), of: aVideoAssetTrack, at: CMTime.zero)
            
        }catch{
            
        }
        
        if audio_count > 0 {
            let aAudioAssetTrack : AVAssetTrack = aAudioAsset.tracks(withMediaType: AVMediaType.audio)[0]
            do{
                try mutableCompositionAudioTrack[0].insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: aVideoAssetTrack.timeRange.duration), of: aAudioAssetTrack, at: CMTime.zero)
                
            }catch{
                
            }
            
        }
        
        totalVideoCompositionInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero,duration: aVideoAssetTrack.timeRange.duration )
        
        let mutableVideoComposition : AVMutableVideoComposition = AVMutableVideoComposition()
        mutableVideoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        
        mutableVideoComposition.renderSize = videoMerger.orientation == VideoMerger.ORI_LAND ? CGSize(width: 1920,height: 1080) : CGSize(width: 1080,height: 1920)
        
        if videoMerger.orientation == VideoMerger.ORI_PORT {
            let instruction = AVMutableVideoCompositionInstruction()
            
            instruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: CMTimeMakeWithSeconds(180, preferredTimescale: 30))
            
            // rotate to portrait
            let transformer = layerInstructionAfterFixingOrientationForAsset(inAsset: aVideoAsset, forTrack: mutableCompositionVideoTrack[0], atTime: CMTime.zero)
            
            instruction.layerInstructions = [transformer]
            
            mutableVideoComposition.instructions = [instruction]
        }
        
        
        //find your video on this URl
        
        let assetExport: AVAssetExportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)!
        assetExport.outputFileType = AVFileType.mp4
        assetExport.outputURL = savePathUrl
        assetExport.shouldOptimizeForNetworkUse = true
        
        if videoMerger.orientation == VideoMerger.ORI_PORT {
            assetExport.videoComposition = mutableVideoComposition
        }
        
        
        assetExport.exportAsynchronously { () -> Void in
            switch assetExport.status {
                
            case AVAssetExportSessionStatus.completed:
                
                //Uncomment this if u want to store your video in asset
                
                //let assetsLib = ALAssetsLibrary()
                //assetsLib.writeVideoAtPathToSavedPhotosAlbum(savePathUrl, completionBlock: nil)
                
                print("success")
                self.openPreviewScreen(savePathUrl)
                try? FileManager.default.removeItem(at: videoUrl)
            case  AVAssetExportSessionStatus.failed:
                print("failed \(assetExport.error)")
            case AVAssetExportSessionStatus.cancelled:
                print("cancelled \(assetExport.error)")
            default:
                print("complete")
            }
        }
        
    }
    
    func layerInstructionAfterFixingOrientationForAsset(inAsset: AVAsset, forTrack inTrack: AVMutableCompositionTrack, atTime inTime: CMTime) -> AVMutableVideoCompositionLayerInstruction {
        let videolayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: inTrack)
        let videoAssetTrack = inAsset.tracks(withMediaType: AVMediaType.video)[0]
        
        var videoAssetOrientation_ = UIImage.Orientation.up
        var isVideoAssetPortrait_ = false;
        
        let videoTransform = videoAssetTrack.preferredTransform
        
        if(videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0)  {
            videoAssetOrientation_ = UIImage.Orientation.right;
            isVideoAssetPortrait_ = true;
            
        }
        if(videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0) {
            
            videoAssetOrientation_ = UIImage.Orientation.left;
            isVideoAssetPortrait_ = true;
        }
        if(videoTransform.a == 1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == 1.0)   {
            videoAssetOrientation_ = UIImage.Orientation.up;
            
        }
        if(videoTransform.a == -1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == -1.0) {
            videoAssetOrientation_ = UIImage.Orientation.down;
            
        }
        //videoAssetOrientation_ = UIImage.Orientation.down;
        var FirstAssetScaleToFitRatio : CGFloat = 1 //1920.0 / videoAssetTrack.naturalSize.width;
        
        if(isVideoAssetPortrait_) {
            FirstAssetScaleToFitRatio = 1080.0 / videoAssetTrack.naturalSize.height
            let FirstAssetScaleFactor = CGAffineTransform(scaleX: FirstAssetScaleToFitRatio,y: FirstAssetScaleToFitRatio);
            videolayerInstruction.setTransform(videoAssetTrack.preferredTransform.concatenating(FirstAssetScaleFactor), at: CMTime.zero)
        }else{
            let FirstAssetScaleFactor = CGAffineTransform(scaleX: FirstAssetScaleToFitRatio,y: FirstAssetScaleToFitRatio)
            let dx : CGFloat = (1920 - 1080) / 4
            videolayerInstruction.setTransform(
                videoAssetTrack.preferredTransform.concatenating(FirstAssetScaleFactor)
                    .concatenating(CGAffineTransform(rotationAngle: CGFloat(Double.pi / 2)))
                    .concatenating(CGAffineTransform(translationX: 1080, y: 0))
                    , at: CMTime.zero)
        }
        videolayerInstruction.setOpacity(1, at: inTime)
        return videolayerInstruction;
    }
}

