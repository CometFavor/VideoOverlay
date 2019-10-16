//
//  VideoMerger.swift
//  VideoTrasition
//
//  Created by MacMaster on 9/17/19.
//  Copyright © 2019 MacMaster. All rights reserved.
//

import Foundation
import AVFoundation

class VideoMerger {
    public static let ORI_LAND = 0;
    public static let ORI_PORT = 1;
    
    var orientation = VideoMerger.ORI_LAND;
    
    var backURL : URL
    var frontURL : URL
    
    var backLayout : DBVideoLayout
    var frontLayout : DBVideoLayout
    
    let video_width = 1920
    let video_height = 1080
    
    var exportURL : URL
    
    var callback : ViewController
    
    var transtionSecondes : Double = 5
    
    init(url1: URL, url2: URL, layout1: DBVideoLayout, layout2: DBVideoLayout, export: URL, vc : ViewController) {
        backURL = url1
        frontURL = url2
        
        backLayout = layout1
        frontLayout = layout2
        
        exportURL = export
        callback = vc
    }
    
    func startRendering() {
        let videoSize = /*orientation == VideoMerger.ORI_PORT ? CGSize(width: video_height, height: video_width) : CGSize(width: video_width, height: video_height)*/ CGSize(width: video_width, height: video_height)
        
        var transition : OverlayRenderer
        
        guard let background_sample_url = orientation == VideoMerger.ORI_LAND ? Bundle.main.url(forResource: "back_landscape", withExtension: "mov") : Bundle.main.url(forResource: "back", withExtension: "mov") else {
            print("Impossible to find the video.")
            return
        }
        
        transition = OverlayRenderer(asset: AVAsset(url: background_sample_url), asset1: AVAsset(url: frontURL), asset2: AVAsset(url: backURL), layout1: backLayout, layout2: frontLayout, videoSize: videoSize)
        
        transition.transtionSecondes = transtionSecondes
        
        let writer : VideoSeqWriter = VideoSeqWriter(outputFileURL: exportURL, audioURL: frontURL, render: transition, videoSize: videoSize)
        
        writer.startRender(vc: callback, url: exportURL)
    }
}
