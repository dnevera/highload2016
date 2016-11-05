//
//  HLTradesFilter.metal
//  HLMoexStatistic
//
//  Created by denis svinarchuk on 14.10.16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

#include <metal_stdlib>
#include "HLCommon.h"

using namespace metal;

/**
 * Фильтр по времени 10:00-10:30
 */
kernel void timeFilterKernel(
                              device Trade *trades [[buffer(0)]],
                              uint tid             [[thread_index_in_threadgroup]],
                              uint gid             [[threadgroup_position_in_grid]],
                              uint threads         [[threads_per_threadgroup]]
                              )
{
    uint  threadId = tid + threads * gid;
    device Trade &trade = trades[threadId];
    
    if ( (trade.time < 100000) || (trade.time > 103000) ) {
        trade.sortable = 0.0;
    }
}
