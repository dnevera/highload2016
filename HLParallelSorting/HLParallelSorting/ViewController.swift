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

let log = false

func quicksort<T: Comparable>(_ a: [T]) -> [T] {
    guard a.count > 1 else { return a }
    let x = a[a.count/2]
    return quicksort(a.filter { $0 < x }) + a.filter { $0 == x } + quicksort(a.filter { $0 > x })
}


class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let count     = 1024 * 1024
        let times     = 3
        
        let randomGPU = RandomNoise(count: count)
        
        let t10 = NSDate.timeIntervalSinceReferenceDate
        
        print("# ... GPU random processing")
        for _ in 0..<times {
            randomGPU.run()
        }
        
        let t11 = NSDate.timeIntervalSinceReferenceDate
        
        var randomCPU = [Float](repeating:0, count: count)
        
        let t20 = NSDate.timeIntervalSinceReferenceDate
        
        print("# ... CPU random processing")
        for _ in 0..<times {
            for i in 0..<count{
                let timer  = UInt32(modf(NSDate.timeIntervalSinceReferenceDate).0)
                randomCPU[i] = Float(arc4random_uniform(timer))/Float(timer)
            }
        }
        
        let t21 = NSDate.timeIntervalSinceReferenceDate
        
        print("# Random of {...n} ∈ ℝ:   \tGPU.time = \((t11-t10)/TimeInterval(times)), CPU.time = \((t21-t20)/TimeInterval(times))")
        
        let bitonicSort = BitonicSort()
        
        bitonicSort.array = randomGPU.array
        
        
        print("# ... GPU sorting")
        let t30 = NSDate.timeIntervalSinceReferenceDate
        for _ in 0..<times {
            bitonicSort.run()
        }
        let t31 = NSDate.timeIntervalSinceReferenceDate
        print("# ... GPU sorting done")
        
        
        var array = [Float](randomGPU.array)
        
        print("# ... DSP sorting")
        let t40 = NSDate.timeIntervalSinceReferenceDate
        for _ in 0..<times {
            vDSP_vsort(&array, vDSP_Length(), 1)
        }
        let t41 = NSDate.timeIntervalSinceReferenceDate
        print("# ... DSP sorting")
        
        array = [Float](randomGPU.array)
        
        print("# ... CPU sorting")
        let t50 = NSDate.timeIntervalSinceReferenceDate
        for _ in 0..<times {
            let _ = quicksort(array)
        }
        let t51 = NSDate.timeIntervalSinceReferenceDate
        print("# ... CPU sorting done")

        if log {
            for i in 0..<bitonicSort.array.count {
                print(i,bitonicSort.array[i])
            }
        }
        
        print("# Sorting of {...n} ∈ ℝ:\tGPU.time = \((t31-t30)/TimeInterval(times)), CPU.time = \((t51-t50)/TimeInterval(times)),  but: DSP.time = \((t41-t40)/TimeInterval(times))!!! ")
        
    }
}

