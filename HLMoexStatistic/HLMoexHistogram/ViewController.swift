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

/**
 * Печатаем в консоль высоту бинов гистораммы
 */
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

/**
 * Гистограмма распределения объемов сделок по часам внутри торговой сессии.
 */
public class TradesHistogram {
    
    public let function:Function

    public init(device:MTLDevice? = nil){
        function  = Function(name: "tradesHistogramKernel", device:device)        
        defer {
            trades = [Trade]()
        }
    }
    
    ///
    /// Считаем что сессия длится 10 часов (так и есть)
    ///
    public var histogram:Array<simd.uint> = Array<simd.uint>(repeating:0, count:10)

    ///
    /// Исходные сделки
    ///
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
                    
                    //
                    // передаем указаель на память с массивом сделок
                    //
                    commandEncoder.setBuffer(buffer, offset: 0, at: 0)
                    
                    //
                    // Сюда получаем бины
                    //
                    commandEncoder.setBuffer(histogramBuffer, offset: 0, at: 1)
                },
                complete: { (commandEncoder) in
                    //
                    // Копируем бины взад, в память CPU
                    //
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
    
    let file = "trades_stock"
    
    if let path = Bundle.main.path(forResource: file, ofType: "json") {
        
        let reader = TradesReader(path: path)
        let timeTradesHistogram = TradesHistogram()
        timeTradesHistogram.trades = reader.trades
        timeTradesHistogram.run()

        let histogram = timeTradesHistogram.histogram
        let m         = Float(histogram.max()!)
        var i         = 10
        
        for b in histogram {
            let length = Int(Float(b)/m * 64)
            print("\(i):00 | ",separator: "", terminator: "")
            for _ in 0...length {
                print("*", separator: "", terminator: "")
            }
            print("")
            i += 1
        }

    }
}
