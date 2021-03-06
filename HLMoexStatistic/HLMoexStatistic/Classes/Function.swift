//
//  Function.swift
//  HLParallelSorting
//
//  Created by Denis Svinarchuk on 08/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

import Foundation
import Metal
import Accelerate.vecLib


/**
 * Copy-paste из HLParallelSorting
 */
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
