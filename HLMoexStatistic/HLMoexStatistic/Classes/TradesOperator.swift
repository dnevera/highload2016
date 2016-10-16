//
//  TheBestTrades.swift
//  HLMoexStatistic
//
//  Created by denis svinarchuk on 16.10.16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

#if os(iOS)
    import UIKit
#endif
import Foundation
import Accelerate
import simd

public class TradesOperator {
    
    public let timeFilterKernel:Function
    public let bitonicSortKernel:Function
    
    var trades:[Trade] = [Trade]() {
        didSet{
            if trades.count>0 {
                buffer = timeFilterKernel.device?.makeBuffer(
                    bytes: trades,
                    length: MemoryLayout<Trade>.size * trades.count,
                    options: .storageModeShared)
            }
        }
    }
    
    public var thebest10:[Trade] {
        get {
            let count = 10
            var bt = [Trade](repeating:Trade(), count:count)
            if let buffer = self.buffer {
                memcpy(&bt, buffer.contents(), MemoryLayout<Trade>.size * count)
            }
            return bt
        }
    }
    
    lazy var buffer:MTLBuffer? = nil
    
    public init(device:MTLDevice? = nil){
        timeFilterKernel  = Function(name: "timeFilterKernel", device:device)
        bitonicSortKernel = Function(name: "bitonicSortKernel", device:timeFilterKernel.device)
        defer {
            trades = [Trade]()
        }
    }
    
    public func run() {
        timeFilter()
    }
    
    public func timeFilter() {
        
        if let buffer = buffer {
            
            if trades.count < timeFilterKernel.maxThreads {
                timeFilterKernel.threads.width = trades.count
                timeFilterKernel.threadgroups.width = 1
            }
            else {
                timeFilterKernel.threads.width = timeFilterKernel.maxThreads
                timeFilterKernel.threadgroups.width = trades.count/timeFilterKernel.maxThreads
            }
            
            timeFilterKernel.execute(
                closure: { (commandEncoder) in
                    commandEncoder.setBuffer(buffer, offset: 0, at: 0)
                },
                complete: { (commandEncoder) in
                    bitonicSort(filteredBuffer: buffer)
            })
        }
    }
    
    lazy var stageBuffer:MTLBuffer? = self.bitonicSortKernel.device?.makeBuffer(
        length: MemoryLayout<simd.uint>.size,
        options: .cpuCacheModeWriteCombined)
    
    lazy var passOfStageBuffer:MTLBuffer? = self.bitonicSortKernel.device?.makeBuffer(
        length: MemoryLayout<simd.uint>.size,
        options: .cpuCacheModeWriteCombined)
    
    lazy var directionBuffer:MTLBuffer? = self.bitonicSortKernel.device?.makeBuffer(
        length: MemoryLayout<simd.uint>.size,
        options: .cpuCacheModeWriteCombined)
    
    public func configure(commandEncoder: MTLComputeCommandEncoder) {
        commandEncoder.setBuffer(stageBuffer,       offset: 0, at: 1)
        commandEncoder.setBuffer(passOfStageBuffer, offset: 0, at: 2)
        commandEncoder.setBuffer(directionBuffer,   offset: 0, at: 3)
    }
    
    func bitonicSort(filteredBuffer:MTLBuffer) {
        let arraySize = simd.uint(trades.count)
        let numStages = Int(log2(Float(arraySize)))
        var dir = simd.uint(0)
        
        memcpy(directionBuffer?.contents(), &dir, (directionBuffer?.length)!)
        
        let count = trades.count
        
        if bitonicSortKernel.maxThreads > count/2 {
            bitonicSortKernel.threads.width = count/2
        }
        else {
            bitonicSortKernel.threads.width = bitonicSortKernel.maxThreads
            bitonicSortKernel.threadgroups.width = count/2/bitonicSortKernel.threads.width
        }
        
        for stage in 0..<numStages {
            
            var stageUint = simd.uint(stage)
            memcpy(stageBuffer?.contents(), &stageUint, (stageBuffer?.length)!)
            
            for passOfStage in 0..<(stage + 1) {
                
                var passOfStageUint = simd.uint(passOfStage)
                
                memcpy(passOfStageBuffer?.contents(), &passOfStageUint, (passOfStageBuffer?.length)!)
                
                bitonicSortKernel.execute(
                    closure: { (commandEncoder) in
                        commandEncoder.setBuffer(filteredBuffer, offset: 0, at: 0)
                        configure(commandEncoder: commandEncoder)
                    },
                    complete: { (commandEncoder) in
                })
            }
        }
    }
}
