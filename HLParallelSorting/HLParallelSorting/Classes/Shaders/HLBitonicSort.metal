//
//  HLBitonicSort.metal
//  HLParallelSorting
//
//  Created by Denis Svinarchuk on 08/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;


// Convert the indices into the sortable values (0 .. large num)
inline float4 indexSortKeys(const int4 indices, device float* array)
{
    return float4(array[indices[0]],
                  array[indices[1]],
                  array[indices[2]],
                  array[indices[3]]);
}

inline int4 vecMask( int4 leftValues, int4 rightValues, bool4 mask )
{
    int4 newValues(0);
    for ( int i = 0; i < 4; ++i )
    {
        newValues[i] = mask[i] ? leftValues[i] : rightValues[i];
    }
    return newValues;
}

inline float4 vecMask( float4 leftValues, float4 rightValues, bool4 mask )
{
    float4 newValues(0);
    for ( int i = 0; i < 4; ++i )
    {
        newValues[i] = mask[i] ? leftValues[i] : rightValues[i];
    }
    return newValues;
}

// Creates a < mask of 4 vectors, and uses the indices as a secondary sort if the values are the same.
// This guarantees that every value will have a definitive < or > relationship, even if they're ==,
// which is necessary when using a bitonic sort.
inline bool4 ltMask( float4 leftValues, float4 rightValues, int4 leftIndices, int4 rightIndices )
{
    bool4 ret(false);
    
    for ( int i = 0; i < 4; ++i )
    {
        if ( leftValues[i] < rightValues[i] )
        {
            ret[i] = true;
        }
        else if ( leftValues[i] == rightValues[i] )
        {
            ret[i] = leftIndices[i] < rightIndices[i];
        }
    }
    return ret;
}


// Based on https://software.intel.com/en-us/articles/bitonic-sorting

kernel void bitonicSortKernel(
                              device float      *array       [[ buffer(0) ]],
                              const device uint &size        [[ buffer(1) ]],
                              constant uint     &stage       [[ buffer(2) ]],
                              constant uint     &passOfStage [[ buffer(3) ]],
                              constant uint     &dir         [[ buffer(4) ]],
                              
                              uint tid [[thread_position_in_grid]]
                              //uint  local_index            [[thread_index_in_threadgroup]],
                              //uint2 groups_per_grid   [[ threadgroups_per_grid ]],
                              //uint2 group_thread_size [[ threads_per_threadgroup ]],
                              //uint2 grid_thread_count [[ threads_per_grid ]],
                              //uint2 group_position    [[ threadgroup_position_in_grid ]]
                              )
{
    uint i = tid;
    
    int4 srcLeft, srcRight;
    float4 valuesLeft, valuesRight;
    bool4 mask;
    bool4 imask10 = (bool4)(0, 0, 1, 1);
    bool4 imask11 = (bool4)(0, 1, 0, 1);
    
    if( stage > 0 )
    {
        // upper level pass, exchange between two fours
        if( passOfStage > 0 )
        {
            uint r = 1 << (passOfStage - 1);
            uint lmask = r - 1;
            uint left = ((i>>(passOfStage-1)) << passOfStage) + (i & lmask);
            uint right = left + r;
            
            srcLeft  = int4(left,left+1,left+2,left+3);
            srcRight = int4(right,right+1,right+2,left+3);
            
            valuesLeft = indexSortKeys( srcLeft, array );
            valuesRight = indexSortKeys( srcRight, array );
            
            mask = ltMask(valuesLeft, valuesRight, srcLeft, srcRight);
            
            int4 imin = vecMask(srcLeft, srcRight, mask);
            
            int4 imax = vecMask(srcLeft, srcRight, ~mask);
            
            if( ( (i>>(stage-1)) & 1) ^ dir )
            {
                //indices[left]  = imax;
                //indices[right] = imin;
            }
            else
            {
                //indices[right] = imax;
                //indices[left]  = imin;
            }
        }
        
        // last pass, sort inside one four
        else
        {
            srcLeft = int4(i,i+1,i+2,i+3);
            valuesLeft = indexSortKeys( srcLeft, array );
            srcRight = srcLeft.zwxy;
            valuesRight = valuesLeft.zwxy;
            
            mask = ltMask(valuesLeft, valuesRight, srcLeft, srcRight) ^ imask10;
            
            if ( ( (i >> stage) & 1) ^ dir )
            {
                srcLeft = vecMask(srcLeft, srcRight, ~mask);
                valuesLeft = vecMask(valuesLeft, valuesRight, ~mask);
                srcRight = srcLeft.yxwz;
                valuesRight = valuesLeft.yxwz;
                
                mask = ltMask(valuesLeft, valuesRight, srcLeft, srcRight) ^ imask11;
                
                //indices[i] = vecMask(srcLeft, srcRight, ~mask);
            }
            else
            {
                srcLeft = vecMask(srcLeft, srcRight, mask);
                valuesLeft = vecMask(valuesLeft, valuesRight, mask);
                srcRight = srcLeft.yxwz;
                valuesRight = valuesLeft.yxwz;
                mask = ltMask(valuesLeft, valuesRight, srcLeft, srcRight) ^ imask11;
                
                //indices[i] = vecMask(srcLeft, srcRight, mask);
            }
        }
    }
    else    // first stage, sort inside one four
    {
        bool4 imask0 = (bool4)(0, 1, 1,  0);
        
        srcLeft     = int4(i,i+1,i+2,i+3);//particleIndices[i];
        srcRight    = srcLeft.yxwz;
        valuesLeft  = indexSortKeys( srcLeft, array );
        valuesRight = valuesLeft.yxwz;
        
        mask = ltMask(valuesLeft, valuesRight, srcLeft, srcRight) ^ imask0;
        
        if ( dir )
        {
            srcLeft = vecMask(srcLeft, srcRight, mask);
            valuesLeft = vecMask(valuesLeft, valuesRight, mask);
        }
        else
        {
            srcLeft = vecMask(srcLeft, srcRight, ~mask);
            valuesLeft = vecMask(valuesLeft, valuesRight, ~mask);
        }
        
        srcRight = srcLeft.zwxy;
        valuesRight = valuesLeft.zwxy;
        
        mask = ltMask(valuesLeft, valuesRight, srcLeft, srcRight) ^ imask10;
        
        int4 indices;
        
        if( (i & 1) ^ dir )
        {
            srcLeft = vecMask(srcLeft, srcRight, mask);
            valuesLeft = vecMask(valuesLeft, valuesRight, mask);
            
            srcRight = srcLeft.yxwz;
            valuesRight = valuesLeft.yxwz;
            
            mask = ltMask(valuesLeft, valuesRight, srcLeft, srcRight) ^ imask11;
            
            indices = vecMask(srcLeft, srcRight, mask);
            
        }
        else
        {
            srcLeft = vecMask(srcLeft, srcRight, ~mask);
            valuesLeft = vecMask(valuesLeft, valuesRight, ~mask);
            
            srcRight = srcLeft.yxwz;
            valuesRight = valuesLeft.yxwz;
            
            mask = ltMask(valuesLeft, valuesRight, srcLeft, srcRight) ^ imask11;
            
            indices = vecMask(srcLeft, srcRight, ~mask);
            
        }
    }
}
