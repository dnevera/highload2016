//
//  Test.swift
//  HLParallelSorting
//
//  Created by Denis Svinarchuk on 12/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

import Foundation
import Accelerate

let log = false
let useQSort = true

extension Float:Sortable{
    public func toInt() -> Int {
        return Int(self * 100000.0)
    }
}

public func test() {
    
    let count     = 1024 * 1024 * 8
    let times     = 3
    
    let randomGPU = RandomNoise(count: count)
    
    print("# ... GPU random processing")
    let t10 = NSDate.timeIntervalSinceReferenceDate
    for _ in 0..<times {
        randomGPU.run()
    }
    let t11 = NSDate.timeIntervalSinceReferenceDate
    
    var randomCPU = [Float](repeating:0, count: count)
    
    print("# ... CPU random processing")
    let t20 = NSDate.timeIntervalSinceReferenceDate
    for _ in 0..<times {
        for i in 0..<count{
            let timer  = UInt32(modf(NSDate.timeIntervalSinceReferenceDate).0)
            randomCPU[i] = Float(arc4random_uniform(timer))/Float(timer)
        }
    }
    let t21 = NSDate.timeIntervalSinceReferenceDate
    
    print("# ... Random of {...n = \(count)} ∈ ℝ:   \tGPU.time = \((t11-t10)/TimeInterval(times)), CPU.time = \((t21-t20)/TimeInterval(times))")
    
    let bitonicSort = BitonicSort()
    
    print("\n# ... GPU sorting (bitonic, threads: \(bitonicSort.maxThreads))")
    var t30 = NSDate.timeIntervalSinceReferenceDate
    for _ in 0..<times {
        bitonicSort.array = randomGPU.array
        bitonicSort.run()
    }
    var t31 = NSDate.timeIntervalSinceReferenceDate
    print("# ... GPU sorting done, time = \((t31-t30)/TimeInterval(times))")
    
    let bitonicCpuSort = BitonicCpuSort()
    
    print("\n# ... CPU sorting (pthreading bitonic, threads: \(bitonicCpuSort.maxThreads))")
    t30 = NSDate.timeIntervalSinceReferenceDate
    for _ in 0..<times {
        bitonicCpuSort.array = randomGPU.array
        bitonicCpuSort.run()
    }
    t31 = NSDate.timeIntervalSinceReferenceDate
    print("# ... CPU sorting done, time = \((t31-t30)/TimeInterval(times))")
    
    var array:[Float]

    print("\n# ... CPU sorting (swift3 sort)")
    t30 = NSDate.timeIntervalSinceReferenceDate
    for _ in 0..<times {
        array = [Float](randomGPU.array)
        let _ = array.sorted {
            return $0<=$1
        }
    }
    t31 = NSDate.timeIntervalSinceReferenceDate
    print("# ... CPU sorting done, time = \((t31-t30)/TimeInterval(times))")
    
    
    print("\n# ... DSP sorting")
    t30 = NSDate.timeIntervalSinceReferenceDate
    for _ in 0..<times {
        array = [Float](randomGPU.array)
        vDSP_vsort(&array, vDSP_Length(), 1)
    }
    t31 = NSDate.timeIntervalSinceReferenceDate
    print("# ... DSP sorting done, time = \((t31-t30)/TimeInterval(times))")
    
    if useQSort {
        print("\n# ... CPU sorting (quicksort)")
        t30 = NSDate.timeIntervalSinceReferenceDate
        for _ in 0..<times {
            array = [Float](randomGPU.array)
            let _ = quicksort(array)
        }
        t31 = NSDate.timeIntervalSinceReferenceDate
        print("# ... CPU sorting done, time = \((t31-t30)/TimeInterval(times))")
    }
    
    print("\n# ... CPU sorting (heapSort)")
    t30 = NSDate.timeIntervalSinceReferenceDate
    for _ in 0..<times {
        array = [Float](randomGPU.array)
        let _ = heapsort(a: array, <)
    }
    t31 = NSDate.timeIntervalSinceReferenceDate
    print("# ... CPU sorting done, time = \((t31-t30)/TimeInterval(times))")
    
    if log {
        for i in 0..<bitonicSort.array.count {
            print(i,bitonicSort.array[i])
        }
    }
    
    print("\nPassed..\n")
}
