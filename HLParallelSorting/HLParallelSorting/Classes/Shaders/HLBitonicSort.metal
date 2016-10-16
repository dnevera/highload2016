//
//  HLBitonicSort.metal
//  HLParallelSorting
//
//  Created by Denis Svinarchuk on 08/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void bitonicSortKernel(
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
    
    uint threadId = tid + threads * gid;
    uint leftId = (threadId % pairDistance) + (threadId / pairDistance) * blockWidth;
    
    uint rightId = leftId + pairDistance;
    
    float leftElement = array[leftId];
    float rightElement = array[rightId];
    
    uint sameDirectionBlockWidth = 1 << stage;
    
    if((threadId/sameDirectionBlockWidth) % 2 == 1) sortIncreasing = 1 - sortIncreasing;
    
    float greater;
    float lesser;
    
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
    
    array[leftId]  = mix(lesser,greater,step(sortIncreasing,0.5));
    array[rightId] = mix(lesser,greater,step(0.5,float(sortIncreasing)));
    
}
