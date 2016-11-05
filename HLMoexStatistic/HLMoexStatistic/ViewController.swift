//
//  ViewController.swift
//  HLMoexStatistic
//
//  Created by Denis Svinarchuk on 13/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

#if os(iOS)
    import UIKit
#endif
import Foundation
import Accelerate
import simd

/**
 * Выводим в консоль тесты.
 */
class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        test()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        print("Усё пропало!")
    }
    
    
}

//
// Сделать выборку по лидерам рынка для определенного времени и выдать список с максимальными объемами
// сделок
//

public func test() {
    
    let file = "trades_stock"
    
    if let path = Bundle.main.path(forResource: file, ofType: "json") {
        
        
        var t10 = Date.timeIntervalSinceReferenceDate
        
        let reader = TradesReader(path: path)
        var trades:[Trade] = reader.trades
        
        var t11 = Date.timeIntervalSinceReferenceDate
        print("reading time = \((t11-t10))s, trades = \(trades.count)")
        
        let k = Int(log2(Float(trades.count)))
        let n = Int(pow(2,Float(k))*2) - trades.count
        
        trades += [Trade](repeating:Trade(), count:n)
        
        let bestTrades = TradesOperator()
        
        bestTrades.trades = trades
        t10 = Date.timeIntervalSinceReferenceDate
        bestTrades.run()
        t11 = Date.timeIntervalSinceReferenceDate
        
        print("filtering GPU time = \((t11-t10))s, trades = \(bestTrades.trades.count)")
        
        for t in bestTrades.thebest10 {
            print(reader.secids[Int(t.id)],t)
        }
    }
    else {
        print("File \(file) does not exist...")
    }
}
