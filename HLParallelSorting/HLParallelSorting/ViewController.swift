//
//  ViewController.swift
//  HLParallelSorting
//
//  Created by Denis Svinarchuk on 08/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

import UIKit
import Accelerate
import simd


public class RandomNoise:ArrayOperator{
    public init(count:Int = 512){
        super.init(name: "randomKernel")
        defer{
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

public class BitonicSorter:ArrayOperator{
    public init(){
        super.init(name: "bitonicSortKernel")
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
        commandEncoder.setBuffer(stageBuffer, offset: 0, at: 2)
        commandEncoder.setBuffer(passOfStageBuffer, offset: 0, at: 3)
        commandEncoder.setBuffer(directionBuffer, offset: 0, at: 4)
    }

//    public func bitonic_stage(stage:Int, index:Int) -> Int {
//        var index = index
//        
//        let numPasses    = stage
//        let blockSize    = 1 << stage
//        var step         = blockSize / 2
//        let subBlockSize = blockSize
//        let numSubBlocks = 1
//        var pass         = 1
//        
//        while pass<=numPasses {
//            
//            pass  += 1
//            step >>= 1
//            index ^= 1
//            
//            var j = 0
//            var x = 0
//            
//            while j<numSubBlocks {
//                j += 1
//                x += subBlockSize
//                
//                print("stage = \(stage) step = \(step), index = \(index), x = \(x)")
//            }
//        }
//        
//        return index
//    }
//
    func bitonicSort() {
        
        var passNum:simd.uint = 0
        let arraySize = simd.uint(array.count)
        let numStages = Int(log2(Float(arraySize))-1)
        
//        var temp = arraySize
//        while temp > 2  {
//            numStages += 1
//            temp >>= 1
//        }
        
        var direction = simd.uint(1)
        
        function.threads.width = 32
        
        for stage in 0..<numStages {
            var passOfStage = stage
            var stageUint = simd.uint(stage)
            while passOfStage>=0 {
                
                print("numStages = \(numStages) \(log2(Float(arraySize))-1), stage = \(stage), passNum = \(passNum) passOfStage = \(passOfStage)")
                
                memcpy(stageBuffer?.contents(), &stageUint, (stageBuffer?.length)!)
                memcpy(passOfStageBuffer?.contents(), &passOfStage, (passOfStageBuffer?.length)!)
                memcpy(directionBuffer?.contents(), &direction, (directionBuffer?.length)!)
                
                let gsz = arraySize / (8)
                
                // NOTE: work size is not 1-per vector.
                // Its the number of quad items in input array
                
                function.threadgroups.width = (Int(passOfStage==0 ? gsz : gsz << 1))
                
                super.run(complete:false)
                
                passOfStage -= 1
                passNum     += 1
            }
        }
        
        flush()
    }
    
    public override func run(complete: Bool=false) {
        
        bitonicSort()
        
//        var k:simd.uint = 2
//        while  k <= simd.uint(array.count) {
//            var j:simd.uint = k>>1
//            while j>0 {
//                print("j = \(j), k = \(k)")
//                memcpy(indexBuffer?.contents(), &j, (indexBuffer?.length)!)
//                memcpy(blockBuffer?.contents(), &k, (blockBuffer?.length)!)
//                super.run(complete:false)
//                j >>= 1
//            }
//            k <<= 1
//        }
//        flush()
    }
}

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        
        let count     = 512
        let times     = 1
        
        let randomGPU = RandomNoise(count: count)

        let t1 = NSDate.timeIntervalSinceReferenceDate

        for _ in 0..<times {
            randomGPU.run()
        }
        
        var randomCPU = [Float](repeating:0, count: count)
        
        let t2 = NSDate.timeIntervalSinceReferenceDate

        for _ in 0..<times {
            for i in 0..<count{
                let timer  = UInt32(modf(NSDate.timeIntervalSinceReferenceDate).0)
                randomCPU[i] = Float(arc4random_uniform(timer))/Float(timer)
            }
        }
        
        let t3 = NSDate.timeIntervalSinceReferenceDate
        
        print(" GPU.time = \((t2-t1)/TimeInterval(times)), CPU.time = \((t3-t2)/TimeInterval(times))")
        
        var revers_array = [Float]()
        
        for i in 0..<count {
            revers_array.append(Float(count-i-1))
        }
        
        let bitonicSorter = BitonicSorter()

        bitonicSorter.array = revers_array //randomGPU.array
        
        bitonicSorter.run()
        
//        for i in 0..<randomGPU.array.count {
//            print(i,randomGPU.array[i])
//        }
        for i in 0..<bitonicSorter.array.count {
            print(i,bitonicSorter.array[i])
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

