//
//  VideoWriter.swift
//  VideoTrasition
//
//  Created by MacMaster on 9/17/19.
//  Copyright © 2019 MacMaster. All rights reserved.
//

import Foundation
import AVKit

final class VideoSeqWriter {
    
    let glContext : EAGLContext
    let ciContext : CIContext
    let writer : AVAssetWriter
    
    class func setupWriter(outputFileURL: URL, videoTmpURL: URL) -> AVAssetWriter {
        let fileManager = FileManager.default
        
        let outputFileExists = fileManager.fileExists(atPath: outputFileURL.path)
        if outputFileExists {
            do {
                try fileManager.removeItem(at: outputFileURL)
                try fileManager.removeItem(at: videoTmpURL)
                print("removed item", outputFileURL)
                
            } catch {
                print("removed item fail ", error)
            }
        }
        
        var error : NSError?
        let writer = try! AVAssetWriter(outputURL: videoTmpURL, fileType: AVFileType.mp4)
        assert(error == nil, "init video writer should not failed: \(error)")
        
        return writer
    }
    
    let videoSize: CGSize
    
    var videoWidth : CGFloat {
        return videoSize.width
    }
    
    var videoHeight : CGFloat {
        return videoSize.height
    }
    
    var videoOutputSettings : [String: Any] {
        return [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoWidthKey: videoWidth,
            AVVideoHeightKey: videoHeight
        ]
    }
    
    var sourcePixelBufferAttributes: [String: Any] {
        return [
            String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA,
            String(kCVPixelBufferWidthKey): videoWidth,
            String(kCVPixelBufferHeightKey): videoHeight
        ]
    }
    
    var videoInput: AVAssetWriterInput!
    var writerInputAdapater: AVAssetWriterInputPixelBufferAdaptor!
    
    let render: OverlayRenderer
    let exportURL: URL
    let audioVideoURL: URL
    let videoOutURL: URL
    
    // create an YMVideoWriter will remove the file specified at outputFileURL if the file exists
    init(outputFileURL: URL, audioURL: URL, render: OverlayRenderer, videoSize: CGSize) {
        
        self.render = render
        self.videoSize = videoSize
        
        exportURL = outputFileURL
        audioVideoURL = audioURL
        
        let dirPaths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        
        let docsURL = dirPaths[0]
        
        let path = docsURL.path.appending("/tmp_audio.mp4")
        videoOutURL = URL.init(fileURLWithPath: path)
        
        glContext = EAGLContext(api: .openGLES2)!
        ciContext = CIContext(eaglContext: glContext)
        writer = VideoSeqWriter.setupWriter(outputFileURL: exportURL, videoTmpURL: videoOutURL)
        
        videoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoOutputSettings)
        writer.add(videoInput)
        
        writerInputAdapater = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: sourcePixelBufferAttributes)
        
        writer.startWriting()
        writer.startSession(atSourceTime: CMTime.zero)
        
    }
    
    
    private func finishWriting(completion: @escaping () -> ()) {
        videoInput.markAsFinished()
        writer.endSession(atSourceTime: lastTime)
        writer.finishWriting(completionHandler: completion)
    }
    
    private var lastTime: CMTime = CMTime.zero
    
    //private var inputQueue = dispatch_queue_create("writequeue.kaipai.tv", DISPATCH_QUEUE_SERIAL)
    
    // write image in CIContext, may failed if no available space
    private func write(buffer: CVPixelBuffer, withPresentationTime time: CMTime) {
        lastTime = time
        
        print("write image at time \(CMTimeGetSeconds(time))")
        
        writerInputAdapater.append(buffer, withPresentationTime: time)
    }
    
    func startRender(vc: ViewController, url : URL) {
        
        videoInput.requestMediaDataWhenReady(on: DispatchQueue.main, using: { [self]() -> Void in
            
            while self.videoInput.isReadyForMoreMediaData {
                
                if let (frame, time) =  self.render.next() {
                    self.write(buffer: frame, withPresentationTime: time)
                } else {
                    self.finishWriting(completion: { () -> () in
                        print("finish writing")
                        //vc.openPreviewScreen(url)
                        vc.appendAudio(audioURL: self.audioVideoURL, videoURL: self.videoOutURL, exportURL: self.exportURL)
                    })
                    break
                }
                
            }
            
        })
        
    }
    
}
