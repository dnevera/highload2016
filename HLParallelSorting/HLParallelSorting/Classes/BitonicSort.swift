//
//  BitonicSort.swift
//  HLParallelSorting
//
//  Created by denis svinarchuk on 11.10.16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

import Foundation
import Accelerate
import simd

public class BitonicSort:ArrayOperator{
    
    public var maxThreads:Int{ return function.maxThreads }

    public override init(name:String = "bitonicSortKernel" ){
        super.init(name: name)
    }
    
    lazy var stageBuffer:MTLBuffer? = self.function.device?.makeBuffer(
        length: MemoryLayout<simd.uint>.size,
        options: .cpuCacheModeWriteCombined)
    
    lazy var passOfStageBuffer:MTLBuffer? = self.function.device?.makeBuffer(
        length: MemoryLayout<simd.uint>.size,
        options: .cpuCacheModeWriteCombined)
    
    lazy var directionBuffer:MTLBuffer? = self.function.device?.makeBuffer(
        length: MemoryLayout<simd.uint>.size,
        options: .cpuCacheModeWriteCombined)
    
    public override func configure(commandEncoder: MTLComputeCommandEncoder) {
        commandEncoder.setBuffer(stageBuffer,       offset: 0, at: 2)
        commandEncoder.setBuffer(passOfStageBuffer, offset: 0, at: 3)
        commandEncoder.setBuffer(directionBuffer,   offset: 0, at: 4)
    }
    
    func bitonicSort() {
        let arraySize = simd.uint(array.count)
        let numStages = Int(log2(Float(arraySize)))
        var direction = simd.uint(1)
        
        memcpy(directionBuffer?.contents(), &direction, (directionBuffer?.length)!)
        
        if function.maxThreads > array.count/2 {
            function.threads.width = array.count/2
            
        }
        else {
            function.threads.width = function.maxThreads
            function.threadgroups.width = array.count/2/function.threads.width
        }
        
        for stage in 0..<numStages {
            
            var stageUint = simd.uint(stage)
            memcpy(stageBuffer?.contents(), &stageUint, (stageBuffer?.length)!)
            
            for passOfStage in 0..<(stage + 1) {
                
                var passOfStageUint = simd.uint(passOfStage)
                
                memcpy(passOfStageBuffer?.contents(), &passOfStageUint, (passOfStageBuffer?.length)!)
                
                super.run(complete:false)
            }
        }
        flush()
    }
    
    func bitonicSortOnePass() {
        super.run()
    }
    
    public override func run(complete: Bool=false) {
        bitonicSort()
    }    
}
