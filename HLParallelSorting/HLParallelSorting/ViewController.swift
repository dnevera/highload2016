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
    
    lazy var timerBuffer:MTLBuffer? = self.function.device?.makeBuffer(length: MemoryLayout<Float>.size, options: .cpuCacheModeWriteCombined)

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
        
        
        let count      = 1024 * 1024
        
        let randomGPU = RandomNoise(count: count)

        let t1 = NSDate.timeIntervalSinceReferenceDate

        randomGPU.run()
        
        var randomCPU = [Float](repeating:0, count: count)
        
        let t2 = NSDate.timeIntervalSinceReferenceDate

        for i in 0..<count{
            let timer  = UInt32(modf(NSDate.timeIntervalSinceReferenceDate).0)
            randomCPU[i] = Float(arc4random_uniform(timer))/Float(timer)
        }
        
        let t3 = NSDate.timeIntervalSinceReferenceDate
        
        print(" GPU.time = \(t2-t1), CPU.time = \(t3-t2)")
        
        let bitonicSorter = BitonicSorter()

        bitonicSorter.array = randomCPU
        
        bitonicSorter.run()
        
        for a in bitonicSorter.array {
           //print(a)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

