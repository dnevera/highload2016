//
//  Test.swift
//  HLParallelSorting
//
//  Created by Denis Svinarchuk on 12/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

#if os(iOS)
    import UIKit
#endif
import Foundation
import Accelerate

let log = false
let useQSort = false

func modelIdentifier() -> String {
    #if os(iOS)
        let gpu_device = MTLCreateSystemDefaultDevice()
        return UIDevice.current.model + ", " + UIDevice.current.systemName + ": " + UIDevice.current.systemVersion + ", " + (gpu_device?.name)!
    #else
        var result = "Unknown Mac"
        var len:size_t = 0
        sysctlbyname("hw.model", nil, &len, nil, 0);
        if len>0 {
            var data:[Int8] = [Int8](repeating:0, count:len)
            sysctlbyname("hw.model", &data, &len, nil, 0)
            if let r = NSString(utf8String: &data) as? String {
                result = r
            }
        }
        
        sysctlbyname("hw.machine", nil, &len, nil, 0);
        if len>0 {
            var data:[Int8] = [Int8](repeating:0, count:len)
            sysctlbyname("hw.machine", &data, &len, nil, 0)
            if let r = NSString(utf8String: &data) as? String {
                result += ", " + r
            }
        }

        var family:Int32 = 0
        sysctlbyname("hw.cpufamily", &family, &len, nil, 0)
        result += ", " + String(format: "%i", family)
        return result
    #endif
}

extension Float:Sortable{
    public func toInt() -> Int {
        return Int(self * 100000.0)
    }
}

let model = modelIdentifier()

public func test() {
    
    print("# ... \(model)")

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

public func testSortProgression(){
    let start  = 1024
    let end    = 1024 * 1024 * 4
    let times  = 3
    
    var points:[Int] = [Int]()
    var gpus:[Float] = [Float]()
    var cpus:[Float] = [Float]()
    var cpus3:[Float] = [Float]()
    var dsp:[Float] = [Float]()
    
    let randomGPU = RandomNoise(count: start)
    let bitonicSort = BitonicSort()
    let bitonicCpuSort = BitonicCpuSort()

    print("\(model)")
    print("Count\t GPU\t CPU\t CPU(bitonic)\t DSP")

    for i in stride(from: start, to: end, by: 1024 * 128) {

        randomGPU.count = i
        randomGPU.run()

        autoreleasepool{
            
            bitonicSort.array = randomGPU.array
            let t10 = NSDate.timeIntervalSinceReferenceDate
            for _ in 0..<times {
                bitonicSort.run()
            }
            let t11 = NSDate.timeIntervalSinceReferenceDate
            
            let t1 = Float(t11-t10)/Float(times)
            
            let t20 = NSDate.timeIntervalSinceReferenceDate
            for _ in 0..<times {
                let array = [Float](randomGPU.array)
                let _ = array.sorted {
                    return $0<=$1
                }
            }
            let t21 = NSDate.timeIntervalSinceReferenceDate
            let t2 = Float(t21-t20)/Float(times)
            
            let t30 = NSDate.timeIntervalSinceReferenceDate
            for _ in 0..<times {
                bitonicCpuSort.array = randomGPU.array
                bitonicCpuSort.run()
            }
            let t31 = NSDate.timeIntervalSinceReferenceDate
            let t3 = Float(t31-t30)/Float(times)

            let t40 = NSDate.timeIntervalSinceReferenceDate
            for _ in 0..<times {
                var array = [Float](randomGPU.array)
                vDSP_vsort(&array, vDSP_Length(), 1)
            }
            let t41 = NSDate.timeIntervalSinceReferenceDate
            let t4 = Float(t41-t40)/Float(times)
            
            
            print("\(i)\t \((t1))\t \(t2)\t \(t3)\t \(t4)")
            
            points.append(i)
            gpus.append(t1)
            cpus.append(t2)
            cpus3.append(t3)
            dsp.append(t4)
        }
    }
    
    var gpu_max_time:Float = 0
    vDSP_maxv(gpus, 1, &gpu_max_time, vDSP_Length(gpus.count))
    
    var cpu_max_time:Float = 0
    vDSP_maxv(cpus, 1, &cpu_max_time, vDSP_Length(cpus.count))

    var cpu3_max_time:Float = 0
    vDSP_maxv(cpus3, 1, &cpu3_max_time, vDSP_Length(cpus3.count))

    var dsp_max_time:Float = 0
    vDSP_maxv(dsp, 1, &dsp_max_time, vDSP_Length(dsp.count))

    let max_time = max(max(max(cpu_max_time,gpu_max_time),cpu3_max_time),dsp_max_time)
    
    var plot_string = "clf; "
    plot_string += "plot(x,g,'g','LineWidth',2); hold on; "
    plot_string += "plot(x,c,'b','LineWidth',2); "
    plot_string += "plot(x,c3,'r','LineWidth',2);"
    plot_string += "plot(x,d,'k','LineWidth',2);"
    plot_string += "axis([\(start) \(end) 0 \(max_time)]); xlabel('Размер'); ylabel('Время создания, сек.'); "
    plot_string += "title('Время сортировки массива случайных чисел от размера. \(model)'); "
    plot_string += "legend('GPU Bitonic Sort','CPU Swift3 Sort','CPU Bitonic Sort','DSP Sort');"
    print("x = \(points); g = \(gpus); c = \(cpus); c3 = \(cpus3); d = \(dsp); hFig = figure(1); set(hFig, 'Position', [100 100 960 640]); \(plot_string)")

}

public func testRandomProgression() {

    let start  = 1024
    let end    = 1024 * 1024 * 4
    let times  = 3
    
    print("\(model)")
    print("Count\t GPU\t CPU")
    let randomGPU = RandomNoise(count: start)

    var points:[Int] = [Int]()
    var gpus:[Float] = [Float]()
    var cpus:[Float] = [Float]()
    
    for i in stride(from: start, to: end, by: 1024 * 128) {
        
        autoreleasepool{
            
            let t10 = NSDate.timeIntervalSinceReferenceDate
            for _ in 0..<times {
                randomGPU.count = i
                randomGPU.run()
            }
            let t11 = NSDate.timeIntervalSinceReferenceDate
            
            let t1 = Float(t11-t10)/Float(times)
            
            var randomCPU = [Float](repeating:0, count: i)
            
            let t20 = NSDate.timeIntervalSinceReferenceDate
            for _ in 0..<times {
                for k in 0..<i{
                    let timer  = UInt32(modf(NSDate.timeIntervalSinceReferenceDate).0)
                    randomCPU[k] = Float(arc4random_uniform(timer))/Float(timer)
                }
            }
            let t21 = NSDate.timeIntervalSinceReferenceDate
            let t2 = Float(t21-t20)/Float(times)

            print("\(i)\t \((t1))\t \(t2)")
            
            points.append(i)
            gpus.append(t1)
            cpus.append(t2)
        }
    }
    
    var gpu_max_time:Float = 0
    vDSP_maxv(gpus, 1, &gpu_max_time, vDSP_Length(cpus.count))

    var cpu_max_time:Float = 0
    vDSP_maxv(cpus, 1, &cpu_max_time, vDSP_Length(cpus.count))
    
    let max_time = max(cpu_max_time,gpu_max_time)
    
    let plot_string = "clf; plot(x,g,'g','LineWidth',2); hold on; plot(x,c,'b','LineWidth',2); axis([\(start) \(end) 0 \(max_time)]); xlabel('Размер'); ylabel('Время создания, сек.'); title('Время создания массива случайных чисел от размера. \(model)'); legend('GPU','CPU');"
    print("x = \(points); g = \(gpus); c = \(cpus); hFig = figure(1); set(hFig, 'Position', [100 100 960 640]); \(plot_string)")
}
