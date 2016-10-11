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
    
    if((threadId/sameDirectionBlockWidth) % 2 == 1)
        sortIncreasing = 1 - sortIncreasing;
    
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


inline void half_cleaner(device float *a, const uint start, const uint end, const uint index, const bool asc){
    
    for(uint i=start; i<end; i+=index){
        
        for(uint j=0; (j<index/2) && (i+j+index/2 < end); ++j)
            
            if( (a[i+j] < a[i+j+index/2]) == asc){
                int t=a[i+j];
                a[i+j]=a[i+j+index/2];
                a[i+j+index/2]=t;
            }
    }
}

inline uint bitonic_sort(device float *a, const uint start, uint end, uint index, bool direction)
{
    uint i = index;
    while(i!=1) {
        half_cleaner(a,start,end,i,direction);
        i/=2;
    }
    return i;
}

inline void bitonic_sort_per_thread(device float *a, uint size, uint tid, uint threads) {
    uint block_size = size/threads;
    for(uint k=4; k<=block_size; k<<=1){
        bool asc=tid%2;
        
        for(int i=tid*block_size;i+k<=(tid+1)*block_size;i+=k)
        {
            bitonic_sort(a, i,i+k,asc,k);
            asc=!asc;
        }
    }
}

kernel void bitonicSortKernelOnePass(
                                     device float      *array [[buffer(0)]],
                                     const device uint &size  [[buffer(1)]],
                                     uint tid [[thread_index_in_threadgroup]],
                                     uint gid [[threadgroup_position_in_grid]],
                                     uint threads [[threads_per_threadgroup]]
                                     )
{
    uint threadId = tid + threads * gid;
    bitonic_sort_per_thread(array,size,threadId,threads);
}

