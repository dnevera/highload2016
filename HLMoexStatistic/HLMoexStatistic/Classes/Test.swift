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
import simd

//
// Сделать выборку по лидерам рынка для определенного времени и выдать список с максимальными объемами
// сделок
//

public func test() {
    
    if let path = Bundle.main.path(forResource: "trades_stock_test", ofType: "json") {
        
        var i = 0
        var trades:[Trade] = [Trade]()
        var secids:[Int:String] = [Int:String]()
        
        var t10 = Date.timeIntervalSinceReferenceDate
        autoreleasepool{
            let reader = ReadTrades(path: path)
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

        let k = Int(log2(Float(trades.count)))
        let n = Int(pow(2,Float(k))*2) - trades.count

        trades += [Trade](repeating:Trade(), count:n)
        
        
        let trades_copy:[Trade] = [Trade](trades)
        
        let bestTrades = TradesOperator()

        bestTrades.trades = trades
        t10 = Date.timeIntervalSinceReferenceDate
        bestTrades.run()
        t11 = Date.timeIntervalSinceReferenceDate
        
        print("filtering GPU time = \((t11-t10))s, trades = \(bestTrades.trades.count)")

        trades = [Trade](trades_copy)
        t10 = Date.timeIntervalSinceReferenceDate
        var bestCPUTrades = trades.map{ (trade) -> Trade in
            if (trade.time<100000 || trade.time>103000) {
                return Trade(id: trade.id, time: trade.time, value: trade.value, sortable: 0)
            }
            return trade
        }
        bestCPUTrades = bestCPUTrades.sorted{
            return $0.sortable>$1.sortable
        }
        t11 = Date.timeIntervalSinceReferenceDate

        print("filtering CPU time = \((t11-t10))s, trades = \(trades.count)")

        for t in bestTrades.thebest10 {
            print(secids[Int(t.id)],t)
        }
    }
}

class ReadTrades {
    
    
    let path: String
    let mode: String = "r"
    let file:UnsafeMutablePointer<FILE>
    
    init(path: String) {
        self.path = path
        let filePath:NSString = path as NSString
        self.file = fopen(filePath.utf8String, self.mode)
    }
    
    func readline() -> String? {
        var line:UnsafeMutablePointer<CChar>? = nil
        var linecap:Int = 0
        defer { free(line) }
        return getline(&line, &linecap, file) > 0 ? String(cString:line!) : nil
    }
    
    func readtrade(line:String) -> (Trade,String)? {
        
        var json = line.substring(with: line.startIndex..<(line.index(before: line.endIndex)))
        json = json.substring(to: json.index(before: json.endIndex))
        
        let first = json.characters.split{$0 == "["}.map(String.init)
        if first.count == 2 {
            let last  = first[1].characters.split{$0 == "]"}.map(String.init)
            if last.count == 1 {
                let s = last[0].replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: " ", with: "")
                let array = s.characters.split{$0 == ","}.map(String.init)
                if array.count == 10 {
                    let a2 = array[2].replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "09", with: "9")
                    let id = array[3].hash
                    let t  = (a2 as NSString).integerValue //time.timeIntervalSince1970
                    let v  = (array[7] as NSString).floatValue
                    return (Trade(id: uint(id), time: uint(t), value: v, sortable: v),array[3])
                }
            }
        }
        
        return nil
    }
    
    deinit {
        fclose(file)
    }
}
