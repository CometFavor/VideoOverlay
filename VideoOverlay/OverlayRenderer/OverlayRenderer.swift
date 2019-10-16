//
//  OverlayRenderer.swift
//  VideoOverlay
//
//  Created by MacMaster on 9/17/19.
//  Copyright © 2019 MacMaster. All rights reserved.
//
//

import Foundation
import MetalKit
import AVKit

final class OverlayRenderer {
    
    var orientation = VideoMerger.ORI_LAND;
    
    var strength = 0.5
    
    //var background : UIImage
    
    let back_sample_reader: VideoSeqReader
    let front_reader: VideoSeqReader
    let back_reader: VideoSeqReader
    
    var backLayout : DBVideoLayout
    var frontLayout : DBVideoLayout
    
    var background_color : UIColor = .red
    
    var outputSize : CGSize
    
    let back_duration : CMTime
    let front_duration : CMTime
    
    var presentationTime : CMTime = CMTime.zero
    
    var frameCount = 0
    
    var transtionSecondes : Double = 5
    
    
    var inputTime: CFTimeInterval?
    
    var pixelBuffer: CVPixelBuffer?
    
    var textureCache: CVMetalTextureCache?
    var commandQueue: MTLCommandQueue
    var computePipelineState: MTLComputePipelineState
    
    
    init(asset: AVAsset, asset1: AVAsset, asset2: AVAsset, layout1: DBVideoLayout, layout2 : DBVideoLayout, videoSize: CGSize) {
        back_sample_reader = VideoSeqReader(asset: asset)
        front_reader = VideoSeqReader(asset: asset1)
        back_reader = VideoSeqReader(asset: asset2)
        
        back_duration = asset.duration
        front_duration = asset1.duration
        
        backLayout = layout1
        frontLayout = layout2
        
        outputSize = videoSize
        
        // Get the default metal device.
        let metalDevice = MTLCreateSystemDefaultDevice()!
        
        // Create a command queue.
        commandQueue = metalDevice.makeCommandQueue()!
        
        // Create the metal library containing the shaders
        let bundle = Bundle.main
        let url = bundle.url(forResource: "default", withExtension: "metallib")
        let library = try! metalDevice.makeLibrary(filepath: url!.path)
        
        // Create a function with a specific name.
        let function = library.makeFunction(name: "produce_frame")!
        
        // Create a compute pipeline with the above function.
        computePipelineState = try! metalDevice.makeComputePipelineState(function: function)
        
        // Initialize the cache to convert the pixel buffer into a Metal texture.
        var textCache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &textCache) != kCVReturnSuccess {
            fatalError("Unable to allocate texture cache.")
        }
        else {
            textureCache = textCache
        }
        
    }
    
    public func initFunction() {
        
    }
    
    func next() -> (CVPixelBuffer, CMTime)? {
        let duration = min(back_duration.seconds, front_duration.seconds)
        
        if let frame = back_sample_reader.getSampleBuffer(), let frame1 = front_reader.next(), let frame3 = back_reader.next() {
            
            let frameRate = front_reader.nominalFrameRate
            presentationTime = CMTimeMake(value: Int64(frameCount * 600), timescale: Int32(600 * frameRate))
            //let image = frame.filterWith(filters: filters)
            let progress = transtionSecondes / duration
            
            if let targetTexture = render(pixelBuffer: frame, pixelBuffer2: frame1, pixelBuffer3: frame3, progress: Float(progress)) {
                var outPixelbuffer: CVPixelBuffer?
                if let datas = targetTexture.buffer?.contents() {
                    CVPixelBufferCreateWithBytes(kCFAllocatorDefault, targetTexture.width,
                                                 targetTexture.height, kCVPixelFormatType_64RGBAHalf, datas,
                                                 targetTexture.bufferBytesPerRow, nil, nil, nil, &outPixelbuffer);
                    if outPixelbuffer != nil {
                        frameCount += 1
                        
                        return (outPixelbuffer!, presentationTime)
                    }
                    
                }
            }
            
            
            frameCount += 1
            
            return (frame, presentationTime)
        }
        
        
        return nil
        
    }
    
    public func render(pixelBuffer: CVPixelBuffer, pixelBuffer2: CVPixelBuffer, pixelBuffer3: CVPixelBuffer, progress: Float) -> MTLTexture? {
        // here the metal code
        // Check if the pixel buffer exists
        
        // Get width and height for the pixel buffer
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Converts the pixel buffer in a Metal texture.
        var cvTextureOut: CVMetalTexture?
        
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache!, pixelBuffer, nil, .bgra8Unorm, width, height, 0, &cvTextureOut)
        guard let cvTexture = cvTextureOut, let inputTexture = CVMetalTextureGetTexture(cvTexture) else {
            print("Failed to create metal texture")
            return nil
        }
        
        
        // Get width and height for the pixel buffer
        let width1 = CVPixelBufferGetWidth(pixelBuffer2)
        let height1 = CVPixelBufferGetHeight(pixelBuffer2)
        
        // Converts the pixel buffer in a Metal texture.
        var cvTextureOut1: CVMetalTexture?
        
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache!, pixelBuffer2, nil, .bgra8Unorm, width1, height1, 0, &cvTextureOut1)
        guard let cvTexture1 = cvTextureOut1, let inputTexture1 = CVMetalTextureGetTexture(cvTexture1) else {
            print("Failed to create metal texture 1")
            return nil
        }
        
        let width2 = CVPixelBufferGetWidth(pixelBuffer3)
        let height2 = CVPixelBufferGetHeight(pixelBuffer3)
        
        // Converts the pixel buffer in a Metal texture.
        var cvTextureOut2: CVMetalTexture?
        
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache!, pixelBuffer3, nil, .bgra8Unorm, width2, height2, 0, &cvTextureOut2)
        guard let cvTexture2 = cvTextureOut2, let inputTexture2 = CVMetalTextureGetTexture(cvTexture2) else {
            print("Failed to create metal texture 2")
            return nil
        }
        
        
        // Check if Core Animation provided a drawable.
        
        // Create a command buffer
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        // Create a compute command encoder.
        let computeCommandEncoder = commandBuffer!.makeComputeCommandEncoder()
        
        // Set the compute pipeline state for the command encoder.
        computeCommandEncoder!.setComputePipelineState(computePipelineState)
        
        // Set the input and output textures for the compute shader.
        computeCommandEncoder!.setTexture(inputTexture2, index: 0)
        computeCommandEncoder!.setTexture(inputTexture1, index: 1)
        computeCommandEncoder!.setTexture(inputTexture, index: 2)
        
        
        let threadGroupCount = MTLSizeMake(8, 8, 1)
        
        let threadGroups: MTLSize = {
            MTLSizeMake(Int(width) / threadGroupCount.width, Int(height) / threadGroupCount.height, 1)
        }()
        // Convert the time in a metal buffer.
        var time = Float(progress)
        computeCommandEncoder!.setBytes(&time, length: MemoryLayout<Float>.size, index: 0)
        
        let backBColor = components(color: backLayout.borderColor);
        var borderColor_r = Float(backBColor![0])
        computeCommandEncoder!.setBytes(&borderColor_r, length: MemoryLayout<Float>.size, index: 1)
        var borderColor_g = Float(backBColor![1])
        computeCommandEncoder!.setBytes(&borderColor_g, length: MemoryLayout<Float>.size, index: 2)
        var borderColor_b = Float(backBColor![2])
        computeCommandEncoder!.setBytes(&borderColor_b, length: MemoryLayout<Float>.size, index: 3)
        var borderColor_a = Float(backLayout.borderColor.cgColor.alpha)
        computeCommandEncoder!.setBytes(&borderColor_a, length: MemoryLayout<Float>.size, index: 4)
        var borderWidth = Float(backLayout.borderWidth)
        computeCommandEncoder!.setBytes(&borderWidth, length: MemoryLayout<Float>.size, index: 5)
        var cornerRadius = Float(backLayout.cornerRadius)
        computeCommandEncoder!.setBytes(&cornerRadius, length: MemoryLayout<Float>.size, index: 6)
        var originX = Float(backLayout.originX)
        computeCommandEncoder!.setBytes(&originX, length: MemoryLayout<Float>.size, index: 7)
        var originY = Float(backLayout.originY)
        computeCommandEncoder!.setBytes(&originY, length: MemoryLayout<Float>.size, index: 8)
        var l_width = Float(backLayout.width)
        computeCommandEncoder!.setBytes(&l_width, length: MemoryLayout<Float>.size, index: 9)
        var l_height = Float(backLayout.height)
        computeCommandEncoder!.setBytes(&l_height, length: MemoryLayout<Float>.size, index: 10)
        
        let frontBColor = components(color: backLayout.borderColor);
        borderColor_r = Float(frontBColor![0])
        computeCommandEncoder!.setBytes(&borderColor_r, length: MemoryLayout<Float>.size, index: 11)
        borderColor_g = Float(frontBColor![1])
        computeCommandEncoder!.setBytes(&borderColor_g, length: MemoryLayout<Float>.size, index: 12)
        borderColor_b = Float(frontBColor![2])
        computeCommandEncoder!.setBytes(&borderColor_b, length: MemoryLayout<Float>.size, index: 13)
        borderColor_a = Float(frontLayout.borderColor.cgColor.alpha)
        computeCommandEncoder!.setBytes(&borderColor_a, length: MemoryLayout<Float>.size, index: 14)
        borderWidth = Float(frontLayout.borderWidth)
        computeCommandEncoder!.setBytes(&borderWidth, length: MemoryLayout<Float>.size, index: 15)
        cornerRadius = Float(frontLayout.cornerRadius)
        computeCommandEncoder!.setBytes(&cornerRadius, length: MemoryLayout<Float>.size, index: 16)
        originX = Float(frontLayout.originX)
        computeCommandEncoder!.setBytes(&originX, length: MemoryLayout<Float>.size, index: 17)
        originY = Float(frontLayout.originY)
        computeCommandEncoder!.setBytes(&originY, length: MemoryLayout<Float>.size, index: 18)
        l_width = Float(frontLayout.width)
        computeCommandEncoder!.setBytes(&l_width, length: MemoryLayout<Float>.size, index: 19)
        l_height = Float(frontLayout.height)
        computeCommandEncoder!.setBytes(&l_height, length: MemoryLayout<Float>.size, index: 20)
        
        let backgroundColor = components(color: background_color);
        borderColor_r = Float(backgroundColor![0])
        computeCommandEncoder!.setBytes(&borderColor_r, length: MemoryLayout<Float>.size, index: 21)
        borderColor_g = Float(backgroundColor![1])
        computeCommandEncoder!.setBytes(&borderColor_g, length: MemoryLayout<Float>.size, index: 22)
        borderColor_b = Float(backgroundColor![2])
        computeCommandEncoder!.setBytes(&borderColor_b, length: MemoryLayout<Float>.size, index: 23)
        borderColor_a = Float(backgroundColor![3])
        computeCommandEncoder!.setBytes(&borderColor_a, length: MemoryLayout<Float>.size, index: 24)
        
        var back_reverse = backLayout.reversed
        computeCommandEncoder!.setBytes(&back_reverse, length: MemoryLayout<Bool>.size, index: 25)
        var front_reverse = frontLayout.reversed
        computeCommandEncoder!.setBytes(&front_reverse, length: MemoryLayout<Bool>.size, index: 26)
        
        // Encode a threadgroup's execution of a compute function
        computeCommandEncoder!.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        
        // End the encoding of the command.
        computeCommandEncoder!.endEncoding()
        
        // Register the current drawable for rendering.
        //commandBuffer!.present(drawable)
        
        // Commit the command buffer for execution.
        commandBuffer!.commit()
        commandBuffer!.waitUntilCompleted()
        
        return inputTexture
    }
    
    func copyBuffer(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        return autoreleasepool(invoking: {() -> CVPixelBuffer? in
            
            let bufferHeight = Int(CVPixelBufferGetHeight(pixelBuffer));
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
            
            var pixelBuffer1: CVPixelBuffer?
            
            let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                         kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue,
                         kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue]
            
            var status = CVPixelBufferCreate(nil, 1920, 1080,
                                             kCVPixelFormatType_32BGRA, attrs as CFDictionary,
                                             &pixelBuffer1)
            guard let result = pixelBuffer1 else {
                print("copy buffer failed")
                return nil
            }
            
            memcpy(CVPixelBufferGetBaseAddress(pixelBuffer1!), CVPixelBufferGetBaseAddress(pixelBuffer), bufferHeight * bytesPerRow)
            
            return pixelBuffer1
        })
        
    }
    
    func getEmptyTexture() -> MTLTexture? {
        return autoreleasepool(invoking: {() -> MTLTexture? in
            
            let background = UIImage(named: "background")!
            
            var pixelBuffer: CVPixelBuffer?
            
            let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                         kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue,
                         kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue]
            
            var status = CVPixelBufferCreate(nil, Int(background.size.width), Int(background.size.height),
                                             kCVPixelFormatType_32BGRA, attrs as CFDictionary,
                                             &pixelBuffer)
            assert(status == noErr)
            
            let coreImage = CIImage(image: background)!
            let context = CIContext(mtlDevice: MTLCreateSystemDefaultDevice()!)
            context.render(coreImage, to: pixelBuffer!)
            
            var textureWrapper: CVMetalTexture?
            
            status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                               self.textureCache!, pixelBuffer!, nil, .bgra8Unorm,
                                                               CVPixelBufferGetWidth(pixelBuffer!), CVPixelBufferGetHeight(pixelBuffer!), 0, &textureWrapper)
            
            guard let cvTexture3 = textureWrapper , let inputTexture3 = CVMetalTextureGetTexture(cvTexture3) else {
                print("Failed to create metal texture sample")
                return nil
            }
            
            return inputTexture3
        })
    }
    
    
    public func getCMSampleBuffer(pixelBuffer : CVPixelBuffer?) -> CMSampleBuffer? {
        
        if pixelBuffer == nil {
            return nil
        }
        
        var info = CMSampleTimingInfo()
        info.presentationTimeStamp = CMTime.zero
        info.duration = CMTime.invalid
        info.decodeTimeStamp = CMTime.invalid
        
        
        var formatDesc: CMFormatDescription? = nil
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer!, formatDescriptionOut: &formatDesc)
        
        var sampleBuffer: CMSampleBuffer? = nil
        
        CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                 imageBuffer: pixelBuffer!,
                                                 formatDescription: formatDesc!,
                                                 sampleTiming: &info,
                                                 sampleBufferOut: &sampleBuffer);
        
        return sampleBuffer!
    }
    
    func components(color : UIColor) -> [CGFloat]? {
        var fRed : CGFloat = 0
        var fGreen : CGFloat = 0
        var fBlue : CGFloat = 0
        var fAlpha: CGFloat = 0
        if color.getRed(&fRed, green: &fGreen, blue: &fBlue, alpha: &fAlpha) {
            return [fRed, fGreen, fBlue, fAlpha];
        } else {
            // Could not extract RGBA components:
            return nil
        }
    }
}
