//
//  ViewController.swift
//  HLMoexHistogram
//
//  Created by denis svinarchuk on 16.10.16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

import UIKit

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


public func test() {
    
    if let path = Bundle.main.path(forResource: "trades_stock_test", ofType: "json") {
        
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
    }
}
