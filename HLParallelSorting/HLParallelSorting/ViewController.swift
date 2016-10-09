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
    
    func B2(){
        
        var asc=false
        let n = function.threads.width
        
        var i = 0
        for _ in 0..<n/2 {
            
            if((array[i]<array[i+1])==asc){
                let t = array[i]
                array[i] = array[i+1]
                array[i+1]=t
            }
            
            asc = !asc
            i += 2
        }
    }
    
    lazy var blockBuffer:MTLBuffer? = self.function.device?.makeBuffer(
        length: MemoryLayout<simd.uint>.size,
        options: .cpuCacheModeWriteCombined)

    lazy var indexBuffer:MTLBuffer? = self.function.device?.makeBuffer(
        length: MemoryLayout<simd.uint>.size,
        options: .cpuCacheModeWriteCombined)

    public override func configure(commandEncoder: MTLComputeCommandEncoder) {
        commandEncoder.setBuffer(blockBuffer, offset: 0, at: 2)
        commandEncoder.setBuffer(indexBuffer, offset: 0, at: 3)
    }

    public override func run(complete: Bool=false) {
        let blocks = array.count/function.threads.width
        function.threadgroups.width = blocks
        var k:simd.uint = 2
        while  k <= simd.uint(array.count) {
            var j:simd.uint = k>>1
            while j>0 {
                memcpy(indexBuffer?.contents(), &j, (indexBuffer?.length)!)
                memcpy(blockBuffer?.contents(), &k, (blockBuffer?.length)!)
                super.run(complete:false)
                j >>= 1
            }
            k <<= 1
        }

        flush()

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
        
        for i in 0..<bitonicSorter.array.count {
           print(i,bitonicSorter.array[i])
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

