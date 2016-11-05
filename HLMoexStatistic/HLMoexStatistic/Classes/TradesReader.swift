//
//  TradesReader.swift
//  HLMoexStatistic
//
//  Created by denis svinarchuk on 16.10.16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

import Foundation

/**
 * Читалка сделок. 
 * Читает все сделки из файла в формате JSON.
 * Каширует в бинарный формат для последующего "мгновенного" чтения, таким образом можно сравнить затраты на обработку JSON и RAW.
 *
 */
public class TradesReader {
    
    let documentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    
    let path: String
    let mode: String = "r"
    let file:UnsafeMutablePointer<FILE>
    
    var cache_path: String
    var cache_secids_path: String
    var cache_file: UnsafeMutablePointer<FILE>? = nil
    var isFileCached = false
    
    public init(path: String, cachable: Bool = true) {
        
        self.path = path
        
        file = fopen((self.path as NSString).utf8String, mode)
        
        let url = URL(fileURLWithPath: path)
        
        let cacheFolder = "cache"
        
        let cacheDirectory = (documentsDirectory as NSString).appendingPathComponent(cacheFolder) as String
        
        if (FileManager.default.fileExists(atPath: cacheDirectory) == false) {
            do {
                try FileManager.default.createDirectory(atPath: cacheDirectory, withIntermediateDirectories:true, attributes:nil)
            }
            catch let error as NSError {
                NSLog("\(error)")
            }
        }
        
        cache_path = String(format: "%@/%@/%@.cache", documentsDirectory, cacheFolder, url.lastPathComponent)
        cache_secids_path = String(format: "%@/%@/%@.secids", documentsDirectory, cacheFolder, url.lastPathComponent)
        
        if (FileManager.default.fileExists(atPath: cache_path) == true) {
            isFileCached = cachable
        }
        else {
            cache_file = fopen((cache_path as NSString).utf8String, "a+")
        }
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
    
    public var secids:[Int:String] = [Int:String]()
    
    public var trades:[Trade] {
        get {
            var trades:[Trade] = [Trade]()
            
            autoreleasepool{
                
                if !isFileCached {
                    
                    var i = 0
                    
                    while let line = self.readline() {
                        autoreleasepool{
                            if let (trade,secid) = self.readtrade(line: line){
                                secids[Int(trade.id)] = secid
                                
                                var addr = unsafeBitCast(trade, to: Trade.self)
                                fwrite(&addr, MemoryLayout<Trade>.size, 1, cache_file)
                                
                                i += 1
                            }
                        }
                    }
                    
                    let data = NSKeyedArchiver.archivedData(withRootObject: secids)
                    
                    do
                    {
                        try data.write(to: URL(fileURLWithPath:cache_secids_path), options: .atomic)
                    }
                    catch let error as NSError {
                        print("Error: secids cache \(cache_secids_path) has not been created: \(error)")
                        remove((cache_path as NSString).utf8String)
                    }
                    
                }
                else {
                    if (FileManager.default.fileExists(atPath: cache_secids_path) == true) {
                        secids = NSKeyedUnarchiver.unarchiveObject(withFile: cache_secids_path) as! [Int:String]
                    }
                    else {
                        print("Error: secids cache \(cache_secids_path) has not been found")
                    }
                }
                
                do
                {
                    
                    fflush(cache_file)
                    
                    let fileDictionary = try FileManager.default.attributesOfItem(atPath: cache_path)
                    let size = Int(fileDictionary[FileAttributeKey.size] as! NSNumber)
                    let count = size/MemoryLayout<Trade>.size
                    
                    let fd_t = open( cache_path, O_RDONLY, S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH)
                    assert(fd_t != -1, "Error: failed to open output file at \""+cache_path+"\"  errno = \(errno)\n")
                    
                    let addr = mmap(nil, size, PROT_READ, MAP_FILE | MAP_SHARED, fd_t, 0)
                    
                    trades = [Trade](repeating:Trade(), count: count)
                    
                    memcpy(&trades, addr, size)
                    
                    assert(munmap(addr, size) == 0, "munmap failed with errno = \(errno)")
                    
                } catch let error as NSError {
                    print(error)
                }
            }
            
            return trades
        }
    }
    
    deinit {
        fclose(cache_file)
        fclose(file)
    }
}
