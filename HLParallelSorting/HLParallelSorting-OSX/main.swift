//
//  main.swift
//  HLParallelSorting-OSX
//
//  Created by Denis Svinarchuk on 12/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

import Foundation
import Accelerate
import Darwin


let NUM_THREADS = 4

//test()

extension Bool {
    init<T : Integer>(_ integer: T) {
        if integer == 0 {
            self.init(false)
        } else {
            self.init(true)
        }
    }
}


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

/// Block-based wrapper for `pthread_join`.
public func pthread_join_result<Result>(
    _ thread: pthread_t,
    _ resultType: Result.Type
    ) -> (CInt, Result?) {
    var threadResultRawPtr: UnsafeMutableRawPointer?
    let result = pthread_join(thread, &threadResultRawPtr)
    if result == 0 {
        let threadResultPtr = threadResultRawPtr!.assumingMemoryBound(
            to: Result.self)
        let threadResult = threadResultPtr.pointee
        threadResultPtr.deinitialize()
        threadResultPtr.deallocate(capacity: 1)
        return (result, threadResult)
    } else {
        return (result, nil)
    }
}

class BitonicCPUSort{
    
    public var array = [Float]()
    
    func BNS_N(a:inout [Float], start:Int, end:Int, pass k: Int, direction asc:Bool){
        //for i in stride(from: start, to: end, by: k) {
        var i = start
        while i<end {
            var j = 0
            while (j<k/2)&&(i+j+k/2<end) {
                if((a[i+j]<a[i+j+k/2])==asc){
                    let t=a[i+j]
                    a[i+j]=a[i+j+k/2]
                    a[i+j+k/2]=t
                }
                j += 1
            }
            i += k
        }
    }
    
    func BNS_2(a:inout [Float], pass k:Int){
        var asc=false;
        var i = 0
        while i<a.count {

        //for i in stride(from: 0, to: a.count, by: k) {
            var j = 0
            while (j<k/2)&&(i+j+k/2<a.count) {
                if((a[i+j]<a[i+j+k/2])==asc){
                    let t=a[i+j]
                    a[i+j]=a[i+j+k/2]
                    a[i+j+k/2]=t
                }
                j += 1
            }
            asc = !asc
            i += k
        }
    }
    
    func bitonic_sort(a:inout [Float], start s:Int, end e:Int, pass:Int, direction:Bool) {
        var k = pass
        while(k != 1) {
            BNS_N(a: &a, start: s, end: e, pass: k, direction: direction)
            k=(k/2)
        }
    }
    
    func merge(a:inout [Float]) {
        
        var k = 2*a.count/NUM_THREADS
        
        while k<=a.count {
            var asc = false
            var i = 0
            while i+k <= a.count {
                bitonic_sort(a: &a, start: i, end: i+k, pass: k, direction: asc)
                i += k
                asc = !asc
            }
            k <<= 1
        }
    }
    
    func pass_sort(tid:Int) {
        
        let num = tid
        
        let n   = array.count
        var k   = 4
        
        while k<=n/NUM_THREADS {
            var asc:Bool = Bool(num%2)
            var i=num*n/NUM_THREADS
            
            while (i+k<=(num+1)*n/NUM_THREADS) {
                
                bitonic_sort(a: &array, start: i, end: i+k, pass: k, direction: asc)
                asc = !asc
                
                i += k
            }
            
            k <<= 1
        }
    }
    
    public func run(){
        
        var threads:[pthread_t] = [pthread_t]()
        
        BNS_2(a: &array, pass: 2)
        
        for i in 0..<NUM_THREADS {
            
            let (_,tid) = pthread_create_block(nil, { (o) -> Int in
                
                self.pass_sort(tid: i)
                
                return i
                }, i)
            threads.append(tid!)
        }
        
        
        for i in 0..<NUM_THREADS {
            pthread_join(threads[i], nil)
        }
        
        merge(a: &array)

    }
}


var bitonicCPUSort = BitonicCPUSort()
var array = [Float](repeatElement(0, count: 1024 * 1024))

for i in 0..<array.count {
    array[i] = Float(array.count - i - 1)
}

bitonicCPUSort.array = array

let t1 = Date.timeIntervalSinceReferenceDate
bitonicCPUSort.run()
let t2 = Date.timeIntervalSinceReferenceDate

print("CPU bitonic = \(t2-t1)")

//print(bitonicCPUSort.array)
