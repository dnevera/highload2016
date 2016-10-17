//
//  HLTradesHistogram.metal
//  HLMoexStatistic
//
//  Created by denis svinarchuk on 16.10.16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

#include <metal_stdlib>
#include "HLCommon.h"
using namespace metal;

kernel void tradesHistogramKernel(
                                  device Trade         *trades    [[buffer(0)]],
                                  device atomic_uint   *histogram [[buffer(1)]],
                                  uint tid             [[thread_index_in_threadgroup]],
                                  uint gid             [[threadgroup_position_in_grid]],
                                  uint threads         [[threads_per_threadgroup]]
                                  )
{
    uint threadId = tid + threads * gid;
    Trade trade = trades[threadId];
    uint i = uint(floor(float(trade.time)/10000.0) - 9.0);

    if (i<10 && trade.time > 0)
        atomic_fetch_add_explicit(&histogram[i], 1, memory_order_relaxed);
}
