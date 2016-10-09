//
//  ViewController.swift
//  HLParallelSorting
//
//  Created by Denis Svinarchuk on 08/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

import UIKit
import Accelerate


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
}

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        
        let count     = 1024 * 1024 * 8
        let times     = 3
        
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
        
        let bitonicSorter = BitonicSorter()

        bitonicSorter.array = randomGPU.array
        
        bitonicSorter.run()
        
        for i in 0..<randomGPU.array.count {
           //print(i,randomGPU.array[i])
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

