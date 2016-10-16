//
//  HLBitonicSort.metal
//  HLParallelSorting
//
//  Created by Denis Svinarchuk on 08/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

#include <metal_stdlib>
#include "HLCommon.h"

using namespace metal;

kernel void bitonicSortKernel(
                              device Trade      *array       [[buffer(0)]],
                              const device uint &stage       [[buffer(1)]],
                              const device uint &passOfStage [[buffer(2)]],
                              const device uint &direction   [[buffer(3)]],
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
    
    Trade leftElement = array[leftId];
    Trade rightElement = array[rightId];
    
    uint sameDirectionBlockWidth = 1 << stage;
    
    if((threadId/sameDirectionBlockWidth) % 2 == 1) sortIncreasing = 1 - sortIncreasing;
    
    Trade greater;
    Trade lesser;
    
    if(leftElement.sortable > rightElement.sortable)
    {
        greater = leftElement;
        lesser  = rightElement;
    }
    else
    {
        greater = rightElement;
        lesser  = leftElement;
    }
    
    if(sortIncreasing == 1)
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
