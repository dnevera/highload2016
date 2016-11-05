//
//  BitonicSort.swift
//  HLParallelSorting
//
//  Created by denis svinarchuk on 11.10.16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

import Foundation
import Accelerate
import simd

/**
 * Битоническая соритровка https://en.wikipedia.org/wiki/Bitonic_sorter
 */
public class BitonicSort:ArrayOperator{
    
    public var maxThreads:Int{ return function.maxThreads }

    public override init(name:String = "bitonicSortKernel" ){
        super.init(name: name)
    }
    
    // Шаг сотрировки, подготовленные для передачи в контекст ядра
    lazy var stageBuffer:MTLBuffer? = self.function.device?.makeBuffer(
        length: MemoryLayout<simd.uint>.size,
        options: .cpuCacheModeWriteCombined)
    
    // Проход сортировки
    lazy var passOfStageBuffer:MTLBuffer? = self.function.device?.makeBuffer(
        length: MemoryLayout<simd.uint>.size,
        options: .cpuCacheModeWriteCombined)
    
    // Направление сортировки
    lazy var directionBuffer:MTLBuffer? = self.function.device?.makeBuffer(
        length: MemoryLayout<simd.uint>.size,
        options: .cpuCacheModeWriteCombined)
    
    ///
    /// Конфигурируем ядро
    ///
    public override func configure(commandEncoder: MTLComputeCommandEncoder) {
        commandEncoder.setBuffer(stageBuffer,       offset: 0, at: 2)
        commandEncoder.setBuffer(passOfStageBuffer, offset: 0, at: 3)
        commandEncoder.setBuffer(directionBuffer,   offset: 0, at: 4)
    }
    
    // Реализация загрузки данных в ядра
    func bitonicSort() {
        let arraySize = simd.uint(array.count)
        let numStages = Int(log2(Float(arraySize)))
        var direction = simd.uint(1)
        
        memcpy(directionBuffer?.contents(), &direction, (directionBuffer?.length)!)
        
        if function.maxThreads > array.count/2 {
            function.threads.width = array.count/2
            
        }
        else {
            //
            // Если не влезли в размер GPU
            //
            function.threads.width = function.maxThreads
            function.threadgroups.width = array.count/2/function.threads.width
        }
        
        for stage in 0..<numStages {
            
            var stageUint = simd.uint(stage)
            
            // перезаписываем шаг в буфер
            memcpy(stageBuffer?.contents(), &stageUint, (stageBuffer?.length)!)
            
            for passOfStage in 0..<(stage + 1) {
                
                var passOfStageUint = simd.uint(passOfStage)
                
                // перезаписываем проход
                memcpy(passOfStageBuffer?.contents(), &passOfStageUint, (passOfStageBuffer?.length)!)
                
                // запускаем
                super.run(complete:false)
            }
        }
        flush()
    }
    

    ///
    /// Запуск сортировки
    ///
    public override func run(complete: Bool=false) {
        bitonicSort()
    }    
}
