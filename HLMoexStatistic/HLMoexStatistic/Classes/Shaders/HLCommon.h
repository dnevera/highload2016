//
//  HLCommon.h
//  HLParallelSorting
//
//  Created by Denis Svinarchuk on 08/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//


#ifndef __HL_COMMON_H__

#ifdef __METAL_VERSION__
#include <metal_stdlib>
using namespace metal;

#else 
#include <simd/simd.h>
#endif

typedef struct {
    uint  id;
    uint  time;
    float value;
    float sortable;
} Trade;

#endif 
