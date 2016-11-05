//
//  HLRandomGenerator.metal
//  HLParallelSorting
//
//  Created by Denis Svinarchuk on 08/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

///
/// Утилиты надерганные из различных эквивалетных реализаций для GLSL
///


// A single iteration of Bob Jenkins' One-At-A-Time hashing algorithm.
inline uint hash( uint x ) {
    x += ( x << 10 );
    x ^= ( x >>  6 );
    x += ( x <<  3 );
    x ^= ( x >> 11 );
    x += ( x << 15 );
    return x;
}

// Compound versions of the hashing algorithm I whipped together.
inline uint hash( uint2 v ) { return hash( v.x ^ hash(v.y)                         ); }
inline uint hash( uint3 v ) { return hash( v.x ^ hash(v.y) ^ hash(v.z)             ); }
inline uint hash( uint4 v ) { return hash( v.x ^ hash(v.y) ^ hash(v.z) ^ hash(v.w) ); }

inline float uintBitsToFloat( uint m ) {
    return as_type<float>(m);
}

inline uint floatBitsToUint( float m ) {
    return as_type<uint>(m);
}

inline uint2 floatBitsToUint( float2 m ) {
    return as_type<uint2>(m);
}

inline uint3 floatBitsToUint( float3 m ) {
    return as_type<uint3>(m);
}

inline uint4 floatBitsToUint( float4 m ) {
    return as_type<uint4>(m);
}


// Construct a float with half-open range [0:1] using low 23 bits.
// All zeroes yields 0.0, all ones yields the next smallest representable value below 1.0.
inline float floatConstruct( uint m ) {
    constexpr uint ieeeMantissa = 0x007FFFFF; // binary32 mantissa bitmask
    constexpr uint ieeeOne      = 0x3F800000; // 1.0 in IEEE binary32
    
    m &= ieeeMantissa;          // Keep only mantissa bits (fractional part)
    m |= ieeeOne;               // Add fractional part to 1.0
    
    float  f = uintBitsToFloat( m );      // Range [1:2]
    return f - 1.0;             // Range [0:1]
}

// Pseudo-random value in half-open range [0:1].
inline float random( float   x ) { return floatConstruct(hash(floatBitsToUint(x))); }
inline float random( float2  v ) { return floatConstruct(hash(floatBitsToUint(v))); }
inline float random( float3  v ) { return floatConstruct(hash(floatBitsToUint(v))); }
inline float random( float4  v ) { return floatConstruct(hash(floatBitsToUint(v))); }


inline float4 permute(float4 x)
{
    return fmod(((x*34.0)+1.0)*x, 289.0);
}

inline float permute(float x)
{
    return floor(fmod(((x*34.0)+1.0)*x, 289.0));
}

inline float4 taylorInvSqrt(float4 r)
{
    return 1.79284291400159 - 0.85373472095314 * r;
}

inline float taylorInvSqrt(float r)
{
    return 1.79284291400159 - 0.85373472095314 * r;
}

inline float4 grad4(float j, float4 ip)
{
    const float4 ones = float4(1.0, 1.0, 1.0, -1.0);
    float4 p,s;
    
    p.xyz = floor( fract (float3(j) * ip.xyz) * 7.0) * ip.z - 1.0;
    p.w = 1.5 - dot(abs(p.xyz), ones.xyz);
    s = float4(min(p, float4(0.0)));
    p.xyz = p.xyz + (s.xyz*2.0 - 1.0) * s.www;
    
    return p;
}

inline float4 snoise(float t, float4 v)
{
    return grad4(0.5, float4(random(mix(random(v),t,t*v))));
}

kernel void randomKernel(
                         device float        *array [[buffer(0)]],
                         const device uint   &size  [[buffer(1)]],
                         const device float  &timer [[buffer(2)]],
                         uint tid      [[thread_position_in_grid]],
                         uint threads [[threads_per_threadgroup]]
                         )
{
    for (uint i = 0; i<size; i+=threads){
        uint   id    = tid+i;
        float4 point = float4(id);
        float4 noise = snoise(timer,point);
        array[id] = dot(point,noise);
    }
}
