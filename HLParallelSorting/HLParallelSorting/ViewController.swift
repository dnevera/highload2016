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
    
    var indicesBuffer:MTLBuffer?
    
    var indices:[int4] = [int4]()

    public override var array: [Float] {
        didSet{
            
            indices.removeAll()
            
            for i in 0..<array.count/4 {
                let index = i * 4
                indices.append(int4(index+0,index+1,index+2,index+3))
            }
            
            indicesBuffer = self.function.device?.makeBuffer(
                bytes: indices,
                length: MemoryLayout<int4>.size * indices.count,
                options: MTLResourceOptions() /*.storageModeShared*/)
        }
    }
    
    public override func configure(commandEncoder: MTLComputeCommandEncoder) {
        commandEncoder.setBuffer(indicesBuffer,     offset: 0, at: 2)
        commandEncoder.setBuffer(stageBuffer,       offset: 0, at: 3)
        commandEncoder.setBuffer(passOfStageBuffer, offset: 0, at: 4)
        commandEncoder.setBuffer(directionBuffer,   offset: 0, at: 5)
    }
    func bitonicSort() {
        
        var passNum:simd.uint = 0
        let arraySize = simd.uint(array.count)
        let numStages = Int(log2(Float(arraySize))-1)
        
        var direction = simd.uint(1)
        
        function.threads.width = 32
        //function.threadgroups.width = array.count/function.threads.width
        
        for stage in 0..<numStages {
            var passOfStage = stage
            var stageUint = simd.uint(stage)
            while passOfStage>=0 {
                
                print("numStages = \(numStages) \(log2(Float(arraySize))-1), stage = \(stage), passNum = \(passNum) passOfStage = \(passOfStage)")
                
                memcpy(stageBuffer?.contents(), &stageUint, (stageBuffer?.length)!)
                memcpy(passOfStageBuffer?.contents(), &passOfStage, (passOfStageBuffer?.length)!)
                memcpy(directionBuffer?.contents(), &direction, (directionBuffer?.length)!)
                
                let gsz = arraySize / 2 / 4
                
                function.threadgroups.width = (Int(passOfStage==0 ? gsz : gsz << 1))
                
                super.run(complete:false)
                
                passOfStage -= 1
                passNum     += 1
            }
        }
        
        //flush()
        
        //let pointer = OpaquePointer(indicesBuffer?.contents())
        let bsize   = MemoryLayout<int4>.size * indices.count
        memset(&indices, 0, bsize)
        memcpy(&indices, indicesBuffer?.contents(), bsize)
    }
    
    public override func run(complete: Bool=false) {
        bitonicSort()
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
        var j = 0
        for i in bitonicSorter.indices {
            print(i)
            for k in 0..<4{
                let index = Int(i[k])
                print(" ", bitonicSorter.array[index], bitonicSorter.array[j])
                j += 1
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

