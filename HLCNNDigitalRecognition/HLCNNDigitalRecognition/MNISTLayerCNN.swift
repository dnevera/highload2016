/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    This is the single layer network where we define and encode the correct layers on a command buffer as needed
*/

import MetalPerformanceShaders
import Accelerate

/**
 
    This class has our entire network with all layers to getting the final label
 
    Resources:
    * [Instructions](https://www.tensorflow.org/versions/r0.8/tutorials/mnist/beginners/index.html#mnist-for-ml-beginners) to run this network on TensorFlow.
 
 */
class MNISTLayerCNN{
    
    static let inputWidth:Int     = 28
    static let inputHeight:Int    = 28
    static let inputNumPixels:Int = 784

    let sid = MPSImageDescriptor(channelFormat: MPSImageFeatureChannelFormat.unorm8, width: 28, height: 28, featureChannels: 1)
    let did = MPSImageDescriptor(channelFormat: MPSImageFeatureChannelFormat.float16, width: 1, height: 1, featureChannels: 10)
    
    var srcImage, dstImage : MPSImage!
    
    
    init(withCommandQueue commandQueueIn: MTLCommandQueue?){
        srcImage = MPSImage(device: commandQueueIn!.device, imageDescriptor: sid)
        dstImage = MPSImage(device: commandQueueIn!.device, imageDescriptor: did)
    }
    
    func updateSource(bytes:UnsafeRawPointer)  {
        srcImage?.texture.replace(region: MTLRegion( origin: MTLOrigin(x: 0, y: 0, z: 0),
                                                                size: MTLSize(width: MNISTLayerCNN.inputWidth, height: MNISTLayerCNN.inputHeight, depth: 1)),
                                             mipmapLevel: 0,
                                             slice: 0,
                                             withBytes: bytes,
                                             bytesPerRow: MNISTLayerCNN.inputWidth,
                                             bytesPerImage: 0)
        
    }
    
    func forward() -> UInt {
        fatalError("Not implemeted yet... ")
    }
    
    func getLabel(finalLayer: MPSImage) -> UInt {
        
        // even though we have 10 labels outputed the MTLTexture format used is RGBAFloat16 thus 3 slices will have 3*4 = 12 outputs
        
        var result_half_array = [UInt16](repeating: 6, count: 12)
        var result_float_array = [Float](repeating: 0.3, count: 10)
        
        for i in 0...2 {
            finalLayer.texture.getBytes(&(result_half_array[4*i]),
                                        bytesPerRow: MemoryLayout<UInt16>.size*1*4,
                                        bytesPerImage: MemoryLayout<UInt16>.size*1*1*4,
                                        from: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                                        size: MTLSize(width: 1, height: 1, depth: 1)),
                                        mipmapLevel: 0,
                                        slice: i)
        }
        
        // we use vImage to convert our data to float16, Metal GPUs use float16 and swift float is 32-bit
        var fullResultVImagebuf = vImage_Buffer(data: &result_float_array, height: 1, width: 10, rowBytes: 10*4)
        var halfResultVImagebuf = vImage_Buffer(data: &result_half_array , height: 1, width: 10, rowBytes: 10*2)
    
        if vImageConvert_Planar16FtoPlanarF(&halfResultVImagebuf, &fullResultVImagebuf, 0) != kvImageNoError {
            print("Error in vImage")
        }
        
        // poll all labels for probability and choose the one with max probability to return
        var max:Float = 0
        var mostProbableDigit = UInt.max
        for i in 0..<result_float_array.count {
            if result_float_array[i] < 0.8 {
                continue
            }
            if(max < result_float_array[i]){
                max = result_float_array[i]
                mostProbableDigit = UInt(i)
            }
        }
        
        return UInt(mostProbableDigit)
    }
    
}




