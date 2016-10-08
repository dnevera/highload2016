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
                              device float      *array [[buffer(0)]],
                              const device uint &size  [[buffer(1)]],
                              uint gid [[thread_position_in_grid]]
                              )
{
    //array[gid] = 256.0;
}
