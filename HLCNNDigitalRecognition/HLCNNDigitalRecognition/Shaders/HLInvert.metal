//
//  HLInvert.metal
//  HLCNNDigitalRecognition
//
//  Created by Denis Svinarchuk on 20/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;



kernel void invertKernel(texture2d<float, access::sample> inTexture [[texture(0)]],
                        texture2d<float, access::write> outTexture [[texture(1)]],
                        uint2 gid [[thread_position_in_grid]])
{
    float4 inColor = inTexture.read(gid);
    inColor.rgb = float3(1)-inColor.rgb;
    outTexture.write(inColor, gid);
}
