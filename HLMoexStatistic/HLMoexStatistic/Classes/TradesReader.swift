//
//  TradesReader.swift
//  HLMoexStatistic
//
//  Created by denis svinarchuk on 16.10.16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

import Foundation

public class TradesReader {
    
    
    let path: String
    let mode: String = "r"
    let file:UnsafeMutablePointer<FILE>
    
    init(path: String) {
        self.path = path
        let filePath:NSString = path as NSString
        self.file = fopen(filePath.utf8String, self.mode)
    }
    
    public func readline() -> String? {
        var line:UnsafeMutablePointer<CChar>? = nil
        var linecap:Int = 0
        defer { free(line) }
        return getline(&line, &linecap, file) > 0 ? String(cString:line!) : nil
    }
    
    public func readtrade(line:String) -> (Trade,String)? {
        
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
