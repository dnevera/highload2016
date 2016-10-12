//
//  BitonicCpuSort.swift
//  HLParallelSorting
//
//  Created by Denis Svinarchuk on 12/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//
import Accelerate
import Darwin


extension Bool {
    init<T : Integer>(_ integer: T) {
        if integer == 0 {
            self.init(false)
        } else {
            self.init(true)
        }
    }
}

public class BitonicCpuSort {
    
    public var array = [Float]()
    
    func bnsBlock(a:inout [Float], i:Int,end:Int,asc:Bool,k:Int)  {
        var j = 0
        while (j<k/2)&&(i+j+k/2<end) {
            if((a[i+j]<a[i+j+k/2])==asc){
                let t=a[i+j]
                a[i+j]=a[i+j+k/2]
                a[i+j+k/2]=t
            }
            j += 1
        }
    }
    func bnsN(a:inout [Float], start:Int, end:Int, pass k: Int, direction asc:Bool){
        var i = start
        while i<end {
            bnsBlock(a: &a, i: i, end: end, asc: asc, k: k)
            i += k
        }
    }
    
    func bns2(a:inout [Float], pass k:Int){
        var asc=false
        var i = 0
        while i<a.count {
            bnsBlock(a: &a, i: i, end: a.count, asc: asc, k: k)
            asc = !asc
            i += k
        }
    }
    
    func bitonicSort(a:inout [Float], start s:Int, end e:Int, pass:Int, direction:Bool) {
        var k = pass
        while(k != 1) {
            bnsN(a: &a, start: s, end: e, pass: k, direction: direction)
            k=(k/2)
        }
    }
    
    let threadNum = ProcessInfo.processInfo.processorCount

    func finalSort(a:inout [Float]) {
        
        var k = 2*a.count/threadNum
        
        while k<=a.count {
            var asc = false
            var i = 0
            while i+k <= a.count {
                bitonicSort(a: &a, start: i, end: i+k, pass: k, direction: asc)
                i += k
                asc = !asc
            }
            k <<= 1
        }
    }
    
    public func run(){
        
        var threads:[pthread_t] = [pthread_t]()
        
        bns2(a: &array, pass: 2)
        
        for i in 0..<threadNum {
            
            let (_,tid) = pthread_create_block(nil, { (o) -> Int in
                
                let num = i
                
                let n   = self.array.count
                var k   = 4
                
                while k<=n/self.threadNum {
                    var asc:Bool = Bool(num%2)
                    var i=num*n/self.threadNum
                    
                    while (i+k<=(num+1)*n/self.threadNum) {
                        
                        self.bitonicSort(a: &(self.array), start: i, end: i+k, pass: k, direction: asc)
                        asc = !asc
                        
                        i += k
                    }
                    
                    k <<= 1
                }
                
                
                return i
                }, i)
            threads.append(tid!)
        }
        
        for i in 0..<threadNum {
            pthread_join(threads[i], nil)
        }
        
        finalSort(a: &array)
    }
}


//
// https://github.com/apple/swift/tree/master/stdlib/private/SwiftPrivatePthreadExtras
//

internal class PthreadBlockContext {
    func run() -> UnsafeMutableRawPointer { fatalError("abstract") }
}

internal class PthreadBlockContextImpl<Argument, Result>: PthreadBlockContext {
    let block: (Argument) -> Result
    let arg: Argument
    
    init(block: @escaping (Argument) -> Result, arg: Argument) {
        self.block = block
        self.arg = arg
        super.init()
    }
    
    override func run() -> UnsafeMutableRawPointer {
        let result = UnsafeMutablePointer<Result>.allocate(capacity: 1)
        result.initialize(to: block(arg))
        return UnsafeMutableRawPointer(result)
    }
}

internal func invokeBlockContext(
    _ contextAsVoidPointer: UnsafeMutableRawPointer?
    ) -> UnsafeMutableRawPointer! {
    let context = Unmanaged<PthreadBlockContext>
        .fromOpaque(contextAsVoidPointer!)
        .takeRetainedValue()
    
    return context.run()
}


/// Block-based wrapper for `pthread_create`.
public func pthread_create_block<Argument, Result>(
    _ attr: UnsafePointer<pthread_attr_t>?,
    _ start_routine: @escaping (Argument) -> Result,
    _ arg: Argument
    ) -> (CInt, pthread_t?) {
    let context = PthreadBlockContextImpl(block: start_routine, arg: arg)
    // We hand ownership off to `invokeBlockContext` through its void context
    // argument.
    let contextAsVoidPointer = Unmanaged.passRetained(context).toOpaque()
    
    var threadID = _make_pthread_t()
    let result = pthread_create(&threadID, attr,
                                { invokeBlockContext($0) }, contextAsVoidPointer)
    if result == 0 {
        return (result, threadID)
    } else {
        return (result, nil)
    }
}

internal func _make_pthread_t() -> pthread_t? {
    return nil
}
