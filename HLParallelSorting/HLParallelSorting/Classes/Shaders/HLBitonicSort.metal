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
                              const device uint &j     [[buffer(2)]],
                              const device uint &k     [[buffer(3)]],
                              uint tid     [[thread_position_in_grid]],
                              //uint gridSize [[threadgroups_per_grid]],
                              uint gridId   [[threadgroup_position_in_grid]],
                              uint threads [[threads_per_threadgroup]]
                              )
{
    unsigned int i, ixj; /* Sorting partners: i and ixj */
    i = tid;// + 2 * gridId;
    ixj = i^j;
    
    //array[i] = float(tid);
    
    /* The threads with the lowest ids sort the array. */
    if ((ixj)>i) {
        if ((i&k)==0) {
            /* Sort ascending */
            if (array[i]>array[ixj]) {
                /* exchange(i,ixj); */
                float temp = array[i];
                array[i] = array[ixj];
                array[ixj] = temp;
                
                //array[i] = i;
            }
        }
        if ((i&k)!=0) {
            /* Sort descending */
            if (array[i]<array[ixj]) {
                /* exchange(i,ixj); */
                float temp = array[i];
                array[i] = array[ixj];
                array[ixj] = temp;
                
                //array[i] = i;

            }
        }
    }
}

