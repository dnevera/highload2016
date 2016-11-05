//
//  Function.swift
//  HLParallelSorting
//
//  Created by Denis Svinarchuk on 08/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

import Foundation
import Metal
import Accelerate.vecLib

/**
 * Обертка к kernel-функциям
 *
 */
public class Function {
   
    ///
    /// Конструктор функции
    ///
    public init(name:String) {
        self.name = name
    }
    

    ///
    /// Спецификация замыкания исполнения
    ///
    public typealias Execution = ((_ encoder:MTLComputeCommandEncoder) -> Void)
    
    ///
    /// Имя в шейдере
    ///
    public let name:String
    
    ///
    /// GPU устройство
    ///
    public let device = MTLCreateSystemDefaultDevice()
    
    ///
    /// Библиотека шейдеров
    ///
    lazy var library:MTLLibrary? = self.device?.newDefaultLibrary()
    
    // Интерфейс к неспециализированной вычислительной функция исполняемой 
    // на каждом ядре GPU
    lazy var kernel:MTLFunction? = self.library?.makeFunction(name: self.name)
    
    // Очередь из коммандных буферов передаваемых в ядра для исполнения
    lazy var commandQueue:MTLCommandQueue? = self.device?.makeCommandQueue()

    // Коммандный буфер. Сюда наливаем всякий неообходимый хлам для передачи контекста
    // исполнения функции в ядре: указатели на память данных, значения переменных 
    // или констант специлизации.
    //
    var commandBuffer:MTLCommandBuffer?  {
        return self.commandQueue?.makeCommandBuffer()
    }

    /// Контейнер потока исполнения команд. Используется для передачи собственно ссылок
    /// на конкретные исполняемые функции и связанные с ними данные, переменные.
    ///
    public lazy var pipeline:MTLComputePipelineState? = {
        if self.kernel == nil {
            fatalError(" *** IMPFunction: \(self.name) has not foumd...")
        }
        do{
            return try self.device?.makeComputePipelineState(function: self.kernel!)
        }
        catch let error as NSError{
            fatalError(" *** IMPFunction: \(error)")
        }
    }()
    
    ///
    /// Максимальное количество потоков (ядер) достпных на GPU
    ///
    public var maxThreads:Int {
        var max=8
        if let p = self.pipeline {
            max = p.maxTotalThreadsPerThreadgroup
        }
        return max
    }
    
    ///
    /// Размерность массива ядер
    ///
    public lazy var threads:MTLSize = {
        return MTLSize(width: self.maxThreads, height: 1,depth: 1)
    }()
    
    ///
    /// Размерность массива груп или блоков исполнения ядер.
    ///
    public var threadgroups = MTLSizeMake(1,1,1)
    
    // Контекст хостовой очереди
    var queue =  DispatchQueue(label: "com.hl.function")
    
    ///
    /// Запускаем вычисления.
    ///
    public final func execute(size:Int, closure: Execution, complete: Execution) {
        if let commandBuffer = commandBuffer {
            queue.sync {
                let commandEncoder = commandBuffer.makeComputeCommandEncoder()
                
                commandEncoder.setComputePipelineState(pipeline!)
                
                closure(commandEncoder)
                
                commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threads)
                commandEncoder.endEncoding()
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                complete(commandEncoder)
                
            }
        }
    }
}
