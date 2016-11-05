//
//  ArrayOperator.swift
//  HLParallelSorting
//
//  Created by Denis Svinarchuk on 08/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

import Foundation
import Accelerate

/*
 * Оператор над массивом
 */
public class ArrayOperator {
    
    ///
    /// Ядерная функция
    ///
    public let function:Function
    
    ///
    /// Сам массив над которым творим безобразия.
    /// Для упрощения восприятия массив представлен типовым Array<Float>.
    /// Однако для ускорения операций обмена данными между хостовой памятью и памтью GPU,
    /// можно выделить класс, например GpuArray, с прямым выделением памяти в GPU без дополнительного
    /// динамического копирования.
    ///
    public var array = [Float]() {
        didSet {
            
            ///
            /// Пока же, без потери общности, просто копируем данные в GPU, при каждом обновлении
            /// массива
            ///
            
            if array.count>0 {

                #if os(OSX)
                    let options:MTLResourceOptions = .storageModeManaged
                    //let options:MTLResourceOptions = .storageModeShared
                #else
                    let options:MTLResourceOptions = .storageModeShared
                #endif

                arrayBuffer = self.function.device?.makeBuffer(
                    bytes: self.array,
                    length: MemoryLayout<Float>.size * self.array.count,
                    options: options)
                
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
    
    ///
    /// Расширение конфигурации запуска ядерных функций
    ///
    public func configure(commandEncoder:MTLComputeCommandEncoder){}

    
    ///
    /// Если данные необходимо вернуть из памяти GPU.
    /// Но помним, что вариант прямого доступа к памяти экономичнее.
    ///
    public func flush() {
        guard let buffer = arrayBuffer else { return }
        
        //
        // Простой вариант копирования данных назад в память CPU, если таки такое копирование неообходимо.
        //
        memcpy(&array, buffer.contents(), buffer.length)
        
        // 
        // Вариант копирования данных через BLAS методы
        //
        // cblas_scopy(Int32(array.count), UnsafePointer<Float>(pointer), 1, &array, 1)
        
        //
        // Вариант копирования через DSP, для некоторых устройств и при некотором объеме данных 
        // может оказаться экономичнее предыдущих
        //
        // vDSP_vclr(&array, 1, vDSP_Length(array.count))
        // vDSP_vadd(UnsafePointer<Float>(pointer), 1, array, 1, &array, 1, vDSP_Length(array.count))
    }
    
    ///
    /// Запускаем операцию
    ///
    public func run(complete:Bool = true){
        if let buffer = arrayBuffer {
            
            function.execute(
                size: array.count,
                closure: { (commandEncoder) in
                    
                    commandEncoder.setBuffer(buffer, offset: 0, at: 0)
                    commandEncoder.setBuffer(arraySizeBuffer, offset: 0, at: 1)
                    
                    configure(commandEncoder: commandEncoder)
                },
                complete: { (commandEncoder) in
                    
                    guard complete else {return}
                    
                    flush()
            })
        }
    }
    
    lazy var arrayBuffer:MTLBuffer? = nil
    lazy var arraySizeBuffer:MTLBuffer? = nil
}
