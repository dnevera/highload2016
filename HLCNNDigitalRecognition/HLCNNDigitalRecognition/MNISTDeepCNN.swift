/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    This is the deep layer network where we define and encode the correct layers on a command buffer as needed
*/

import MetalPerformanceShaders



public class Function {
    
    public typealias Execution = ((_ encoder:MTLComputeCommandEncoder) -> Void)
    
    public let name:String
    
    public var device:MTLDevice?
    
    lazy var library:MTLLibrary? = self.device?.newDefaultLibrary()
    
    lazy var kernel:MTLFunction? = self.library?.makeFunction(name: self.name)
    
    lazy var commandQueue:MTLCommandQueue? = self.device?.makeCommandQueue()
    
    public init(name:String, device:MTLDevice? = nil) {
        if device != nil {
            self.device = device
        }
        else {
            self.device = MTLCreateSystemDefaultDevice()
        }
        self.name = name
    }
    
    var commandBuffer:MTLCommandBuffer?  {
        return self.commandQueue?.makeCommandBuffer()
    }
    
    public lazy var pipeline:MTLComputePipelineState? = {
        if self.kernel == nil {
            fatalError(" *** IMPFunction: \(self.name) has not foumd...")
        }
        do{
            return try self.device?.makeComputePipelineState(function: self.kernel!)
        }
        catch let error as NSError{
            fatalError(" *** IMPFunction: \(error)")
        }
    }()
    
    public var maxThreads:Int {
        var max=8
        if let p = self.pipeline {
            max = p.maxTotalThreadsPerThreadgroup
        }
        return max
    }
    
    public lazy var threads:MTLSize = {
        return MTLSize(width: self.maxThreads, height: 1,depth: 1)
    }()
    
    public var threadgroups = MTLSizeMake(1,1,1)
    
    var queue =  DispatchQueue(label: "com.hl.function")
    
    public final func execute(closure: Execution, complete: Execution) {
        if let commandBuffer = commandBuffer {
            queue.sync {
                let commandEncoder = commandBuffer.makeComputeCommandEncoder()
                
                commandEncoder.setComputePipelineState(pipeline!)
                
                closure(commandEncoder)
                
                commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threads)
                commandEncoder.endEncoding()
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                complete(commandEncoder)
            }
        }
    }
}


/**
 
    This class has our entire network with all layers to getting the final label
 
    Resources:
    * [Instructions](https://www.tensorflow.org/versions/r0.8/tutorials/mnist/pros/index.html#deep-mnist-for-experts) to run this network on TensorFlow.
 
 */
class MNISTDeepCNN: MNISTLayerCNN{
    // MPSImageDescriptors for different layers outputs to be put in
    let c1id  = MPSImageDescriptor(channelFormat: MPSImageFeatureChannelFormat.float16, width: MNISTLayerCNN.inputWidth, height: MNISTLayerCNN.inputHeight, featureChannels: 32)
    let p1id  = MPSImageDescriptor(channelFormat: MPSImageFeatureChannelFormat.float16, width: MNISTLayerCNN.inputWidth/2, height: MNISTLayerCNN.inputHeight/2, featureChannels: 32)
    let c2id  = MPSImageDescriptor(channelFormat: MPSImageFeatureChannelFormat.float16, width: MNISTLayerCNN.inputWidth/2, height: MNISTLayerCNN.inputHeight/2, featureChannels: 64)
    let p2id  = MPSImageDescriptor(channelFormat: MPSImageFeatureChannelFormat.float16, width: MNISTLayerCNN.inputWidth/4 , height: MNISTLayerCNN.inputHeight/4 , featureChannels: 64)
    let fc1id = MPSImageDescriptor(channelFormat: MPSImageFeatureChannelFormat.float16, width: 1 , height: 1 , featureChannels: 1024)
    
    // MPSImages and layers declared
    var c1Image, c2Image, p1Image, p2Image, fc1Image: MPSImage
    var conv1, conv2: MPSCNNConvolution
    var fc1, fc2: MPSCNNFullyConnected
    var pool: MPSCNNPoolingMax
    var relu: MPSCNNNeuronReLU
    var softmax : MPSCNNSoftMax

    let invert:Function!

    var commandQueue:MTLCommandQueue!
    
    override init(withCommandQueue commandQueueIn: MTLCommandQueue? = nil) {
        // use device for a little while to initialize
        
        
        if let inc = commandQueueIn {
            commandQueue = inc
        }
        else {
            let device = MTLCreateSystemDefaultDevice()
            commandQueue = (device?.makeCommandQueue())!
        }
        
        let device = commandQueue.device
        
        invert = Function(name: "invertKernel", device: device)
        
        pool = MPSCNNPoolingMax(device: device, kernelWidth: 2, kernelHeight: 2, strideInPixelsX: 2, strideInPixelsY: 2)
        pool.offset = MPSOffset(x: 1, y: 1, z: 0);
        pool.edgeMode = MPSImageEdgeMode.clamp
        relu = MPSCNNNeuronReLU(device: device, a: 0)
        
        
        
        // Initialize MPSImage from descriptors
        c1Image     = MPSImage(device: device, imageDescriptor: c1id)
        p1Image     = MPSImage(device: device, imageDescriptor: p1id)
        c2Image     = MPSImage(device: device, imageDescriptor: c2id)
        p2Image     = MPSImage(device: device, imageDescriptor: p2id)
        fc1Image    = MPSImage(device: device, imageDescriptor: fc1id)
        
        
        // setup convolution layers
        conv1 = SlimMPSCNNConvolution(kernelWidth: 5,
                                      kernelHeight: 5,
                                      inputFeatureChannels: 1,
                                      outputFeatureChannels: 32,
                                      neuronFilter: relu,
                                      device: device,
                                      kernelParamsBinaryName: "conv1")
        
        conv2 = SlimMPSCNNConvolution(kernelWidth: 5,
                                      kernelHeight: 5,
                                      inputFeatureChannels: 32,
                                      outputFeatureChannels: 64,
                                      neuronFilter: relu,
                                      device: device,
                                      kernelParamsBinaryName: "conv2")
        
        
        // same as a 1x1 convolution filter to produce 1x1x10 from 1x1x1024
        fc1 = SlimMPSCNNFullyConnected(kernelWidth: 7,
                                       kernelHeight: 7,
                                       inputFeatureChannels: 64,
                                       outputFeatureChannels: 1024,
                                       neuronFilter: nil,
                                       device: device,
                                       kernelParamsBinaryName: "fc1")
        
        fc2 = SlimMPSCNNFullyConnected(kernelWidth: 1,
                                       kernelHeight: 1,
                                       inputFeatureChannels: 1024,
                                       outputFeatureChannels: 10,
                                       neuronFilter: nil,
                                       device: device,
                                       kernelParamsBinaryName: "fc2")
        
        // prepare softmax layer to be applied at the end to get a clear label
        softmax = MPSCNNSoftMax(device: device)

        super.init(withCommandQueue: commandQueue)
    }

    let threads = MTLSizeMake(16, 16, 1);

    override func forward() -> UInt{
        var label = UInt(99)
        autoreleasepool{
            
            let threadgroups = MTLSizeMake(
                (srcImage.texture.width  + threads.width ) / threads.width ,
                (srcImage.texture.height + threads.height) / threads.height,
                1);
            
            
//            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
//                pixelFormat: srcImage.pixelFormat,
//                width: srcImage.texture.width,
//                height: srcImage.texture.height, mipmapped: false)

            let commandBuffer = commandQueue.makeCommandBuffer()

            let commandEncoder = commandBuffer.makeComputeCommandEncoder()

            commandEncoder.setComputePipelineState(invert.pipeline!)
            
            commandEncoder.setTexture(srcImage.texture, at: 0)
            commandEncoder.setTexture(srcImage.texture, at: 1)
            
            commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threads)
            commandEncoder.endEncoding()
            
            let finalLayer = MPSImage(device: commandBuffer.device, imageDescriptor: did)
            
            conv1.encode(commandBuffer: commandBuffer, sourceImage: srcImage, destinationImage: c1Image)
            
            pool.encode   (commandBuffer: commandBuffer, sourceImage: c1Image   , destinationImage: p1Image)
            conv2.encode  (commandBuffer: commandBuffer, sourceImage: p1Image   , destinationImage: c2Image)
            pool.encode   (commandBuffer: commandBuffer, sourceImage: c2Image   , destinationImage: p2Image)
            fc1.encode    (commandBuffer: commandBuffer, sourceImage: p2Image   , destinationImage: fc1Image)
            fc2.encode    (commandBuffer: commandBuffer, sourceImage: fc1Image  , destinationImage: dstImage!)
            softmax.encode(commandBuffer: commandBuffer, sourceImage: dstImage!  , destinationImage: finalLayer)
            
            commandBuffer.addCompletedHandler { commandBuffer in
                label = self.getLabel(finalLayer: finalLayer)
            }
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
        }
        return label
    }
}
