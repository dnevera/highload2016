//
//  ViewController.swift
//  HLMoexHistogram
//
//  Created by denis svinarchuk on 16.10.16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

import UIKit
import Accelerate
import simd

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        test()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

public class TradesHistogram {
    
    public let function:Function

    public init(device:MTLDevice? = nil){
        function  = Function(name: "tradesHistogramKernel", device:device)        
        defer {
            trades = [Trade]()
        }
    }
    
    public var histogram:Array<simd.uint> = Array<simd.uint>(repeating:0, count:10)

    public var trades:[Trade] = [Trade]() {
        didSet{
            if trades.count>0 {
                buffer = function.device?.makeBuffer(
                    bytes: trades,
                    length: MemoryLayout<Trade>.size * trades.count,
                    options: .storageModeShared)
            }
        }
    }
    
    public func run() {
        
        if let buffer = buffer {
            
            if trades.count < function.maxThreads {
                function.threads.width = trades.count
                function.threadgroups.width = 1
            }
            else {
                function.threads.width = function.maxThreads
                function.threadgroups.width = trades.count/function.maxThreads
            }
            
            function.execute(
                closure: { (commandEncoder) in
                    commandEncoder.setBuffer(buffer, offset: 0, at: 0)
                    commandEncoder.setBuffer(histogramBuffer, offset: 0, at: 1)
                },
                complete: { (commandEncoder) in
                    if let h = histogramBuffer {
                        memcpy(&histogram, h.contents(), h.length)
                    }
            })
        }
    }

    lazy var buffer:MTLBuffer? = nil
    
    lazy var histogramBuffer:MTLBuffer? = self.function.device?.makeBuffer(
        length: MemoryLayout<simd.uint>.size * self.histogram.count,
        options: .storageModeShared)

}

public func test() {
    
    if let path = Bundle.main.path(forResource: "trades_stock", ofType: "json") {
        
        var i = 0
        var trades:[Trade] = [Trade]()
        var secids:[Int:String] = [Int:String]()
        
        var t10 = Date.timeIntervalSinceReferenceDate
        autoreleasepool{
            let reader = TradesReader(path: path)
            while let line = reader.readline() {
                autoreleasepool{
                    if let (trade,secid) = reader.readtrade(line: line){
                        secids[Int(trade.id)] = secid
                        trades.append(trade)
                        i += 1
                    }
                }
            }
        }
        
        var t11 = Date.timeIntervalSinceReferenceDate
        print("reading time = \((t11-t10))s, trades = \(trades.count)")
        
        let timeTradesHistogram = TradesHistogram()
        timeTradesHistogram.trades = trades
        t10 = Date.timeIntervalSinceReferenceDate
        timeTradesHistogram.run()
        t11 = Date.timeIntervalSinceReferenceDate
        print("histogram GPU computation time = \((t11-t10))s, trades = \(trades.count)")

        var histogram:[Int] = [Int](repeating:0, count:10)
        t10 = Date.timeIntervalSinceReferenceDate
        for t in trades {
            let i = Int(t.time/10000 - 9)
            guard i>=0 && i<histogram.count else { continue }
            histogram[i] += 1
        }
        t11 = Date.timeIntervalSinceReferenceDate
        print("histogram CPU computation time = \((t11-t10))s, trades = \(trades.count)")

    }
}
