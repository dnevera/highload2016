//
//  RandomNoise.swift
//  HLParallelSorting
//
//  Created by Denis Svinarchuk on 11/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

import Foundation
import Accelerate
import simd


public class RandomNoise:ArrayOperator{
    public init(count:Int = 512){
        
        super.init(name: "randomKernel")
        defer{
            self.count = count
        }
    }
    
    var count:Int = 512 {
        didSet {
            array =  [Float](repeating:0, count:count)
        }
    }
    
    lazy var timerBuffer:MTLBuffer? = self.function.device?.makeBuffer(
        length: MemoryLayout<Float>.size,
        options: .cpuCacheModeWriteCombined)
    
    public override func configure(commandEncoder: MTLComputeCommandEncoder) {
        let timer  = UInt32(modf(NSDate.timeIntervalSinceReferenceDate).0)
        var rand = Float(arc4random_uniform(timer))/Float(timer)
        memcpy(timerBuffer?.contents(), &rand, MemoryLayout<Float>.size)
        commandEncoder.setBuffer(timerBuffer, offset: 0, at: 2)
    }
}

