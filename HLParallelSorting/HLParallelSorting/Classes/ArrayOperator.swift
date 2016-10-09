//
//  ArrayOperator.swift
//  HLParallelSorting
//
//  Created by Denis Svinarchuk on 08/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

import Foundation
import Accelerate

public class ArrayOperator {
    
    public let function:Function
    
    public var array = [Float]() {
        didSet {
            if array.count>0 {

                arrayBuffer = self.function.device?.makeBuffer(
                    bytes: self.array,
                    length: MemoryLayout.size(ofValue: self.array),
                    options: .cpuCacheModeWriteCombined /*MTLResourceOptions()*/)
                
                var size = array.count
                
                arraySizeBuffer = self.function.device?.makeBuffer(
                    bytes: &size,
                    length: MemoryLayout.size(ofValue: size),
                    options: .cpuCacheModeWriteCombined)
            }
        }
    }
    
    public init(name: String){
        function = Function(name: name)
    }
    
    public func configure(commandEncoder:MTLComputeCommandEncoder){}
    
    public func run(){
        if let buffer = arrayBuffer {
            
            function.execute(
                size: array.count,
                closure: { (commandEncoder) in
                    
                    commandEncoder.setBuffer(buffer, offset: 0, at: 0)
                    commandEncoder.setBuffer(arraySizeBuffer, offset: 0, at: 1)
                    
                    configure(commandEncoder: commandEncoder)
                    
                },
                complete: { (commandEncoder) in                    
                    let pointer = OpaquePointer(buffer.contents())
                    
                    //
                    // V.1
                    //
                    //let bsize   = MemoryLayout<Float>.size * array.count
                    //memset(&array, 0, bsize)
                    //memcpy(&array, UnsafePointer<Float>(pointer), bsize)
                    
                    //
                    // V.2
                    //
                    vDSP_vclr(&array, 1, vDSP_Length(array.count))
                    //
                    // V.2.1
                    //
                    //cblas_scopy(Int32(array.count), UnsafePointer<Float>(pointer), 1, &array, 1)
                    //
                    //
                    vDSP_vadd(UnsafePointer<Float>(pointer), 1, array, 1, &array, 1, vDSP_Length(array.count))
            })
        }
    }
    
    lazy var arrayBuffer:MTLBuffer? = nil
    lazy var arraySizeBuffer:MTLBuffer? = nil
}
