//
//  HLBitonicSort.metal
//  HLParallelSorting
//
//  Created by Denis Svinarchuk on 08/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

/**
 * Релизация kernel-функции MSL
 */
kernel void bitonicSortKernel(
                              // указатель на память массива чисел
                              device float      *array       [[buffer(0)]],
                              // ссылка на значение шага сортировки
                              const device uint &stage       [[buffer(2)]],
                              // ссылка на номер прохода
                              const device uint &passOfStage [[buffer(3)]],
                              // ссылка на направление сортировки
                              const device uint &direction   [[buffer(4)]],
                              // индекс потока (ядра)
                              uint tid [[thread_index_in_threadgroup]],
                              // индекс группы потоков (ядер)
                              uint gid [[threadgroup_position_in_grid]],
                              // количество запущеных потоков
                              uint threads [[threads_per_threadgroup]]
                              )
{
    uint sortIncreasing = direction;
    
    uint pairDistance = 1 << (stage - passOfStage);
    uint blockWidth   = 2 * pairDistance;
    
    // абсолютный индекс ядра
    uint threadId = tid + threads * gid;
    
    // индекс первого сравниваемого элемента
    uint leftId = (threadId % pairDistance) + (threadId / pairDistance) * blockWidth;
    
    // индекс второго
    uint rightId = leftId + pairDistance;
    
    // значения
    float leftElement = array[leftId];
    float rightElement = array[rightId];
    
    // ширина блока в котором проводится сортировка
    uint sameDirectionBlockWidth = 1 << stage;
    
    // направление сравнения в блоке
    if((threadId/sameDirectionBlockWidth) % 2 == 1) sortIncreasing = 1 - sortIncreasing;
    
    float greater;
    float lesser;
    
    
    //
    // Неоптимизированый для GPU flow-control
    //
    if(leftElement > rightElement)
    {
        greater = leftElement;
        lesser  = rightElement;
    }
    else
    {
        greater = rightElement;
        lesser  = leftElement;
    }
    
    if(sortIncreasing)
    {
        array[leftId]  = lesser;
        array[rightId] = greater;
    }
    else
    {
        array[leftId]  = greater;
        array[rightId] = lesser;
    }
}

/**
 * Релизация kernel-функции MSL с оптимизацией по flow-control
 */
kernel void bitonicSortKernelOptimized(
                                       device float      *array       [[buffer(0)]],
                                       const device uint &stage       [[buffer(2)]],
                                       const device uint &passOfStage [[buffer(3)]],
                                       const device uint &direction   [[buffer(4)]],
                                       uint tid [[thread_index_in_threadgroup]],
                                       uint gid [[threadgroup_position_in_grid]],
                                       uint threads [[threads_per_threadgroup]]
                                       )
{
    uint sortIncreasing = direction;
    
    uint pairDistance = 1 << (stage - passOfStage);
    uint blockWidth   = 2 * pairDistance;
    
    uint globalPosition = threads * gid;
    uint threadId = tid + globalPosition;
    uint leftId = (threadId % pairDistance) + (threadId / pairDistance) * blockWidth;
    
    uint rightId = leftId + pairDistance;
    
    float leftElement  = array[leftId];
    float rightElement = array[rightId];
    
    uint sameDirectionBlockWidth = 1 << stage;
    
    if((threadId/sameDirectionBlockWidth) % 2 == 1) sortIncreasing = 1 - sortIncreasing;
    
    float greater = mix(leftElement,rightElement,step(leftElement,rightElement));
    float lesser  = mix(leftElement,rightElement,step(rightElement,leftElement));
    
    //
    // Заменяет if/else, но потенциально быстрее в силу того, что не блокирует блок ветвлений.
    // Особенно это хорошо заметно для старых типов GPU (A7, к примеру).
    // Однако, в современных реализациях производительность обработки ветвлений в GPU приблизилась
    // к эквивалентам CPU. Но, в целом, на больших массивах, разница все еще остается заметной. 
    //
    array[leftId]  = mix(lesser,greater,step(sortIncreasing,0.5));
    array[rightId] = mix(lesser,greater,step(0.5,float(sortIncreasing)));
    
}
