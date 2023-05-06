#ifndef HSSSS_SSRT_CGINC
#define HSSSS_SSRT_CGINC

#include "UnityCG.cginc"

uniform Texture2D _MainTex;
uniform SamplerState sampler_MainTex;
uniform float4 _MainTex_TexelSize;

uniform Texture2D _CameraDepthTexture;
uniform SamplerState sampler_CameraDepthTexture;

uniform Texture2D _CameraGBufferTexture0;
uniform SamplerState sampler_CameraGBufferTexture0;

uniform Texture2D _CameraGBufferTexture1;
uniform SamplerState sampler_CameraGBufferTexture1;

uniform Texture2D _CameraGBufferTexture2;
uniform SamplerState sampler_CameraGBufferTexture2;

uniform Texture2D _CameraGBufferTexture3;
uniform SamplerState sampler_CameraGBufferTexture3;

uniform Texture2D _SSGITemporalAOBuffer;
uniform SamplerState sampler_SSGITemporalAOBuffer;

uniform Texture2D _SSGITemporalGIBuffer;
uniform SamplerState sampler_SSGITemporalGIBuffer;

uniform float4x4 _WorldToViewMatrix;
uniform float4x4 _ViewToWorldMatrix;

uniform float4x4 _ViewToClipMatrix;
uniform float4x4 _ClipToViewMatrix;

uniform float4x4 _PrevWorldToViewMatrix;
uniform float4x4 _PrevViewToWorldMatrix;

uniform float4x4 _PrevViewToClipMatrix;
uniform float4x4 _PrevClipToViewMatrix;

#define FULL_PI 3.14159265359f
#define HALF_PI 1.57079632679f

#define UV_SPLIT 2
#define KERNEL_TAPS 2

static const half torusKernel[5] =
{
    0.0625h,
    0.2500h,
    0.3750h,
    0.2500h,
    0.0625h
};

//
// sample texel
//
inline half4 SampleTexel(float2 uv)
{
    return _MainTex.Sample(sampler_MainTex, uv);
}

inline half4 SampleTexel(float2 uv, int2 offset)
{
    return _MainTex.Sample(sampler_MainTex, uv, offset);
}

//
// depth buffer
//
inline float SampleZBuffer(float2 uv)
{
    return _CameraDepthTexture.Sample(sampler_CameraDepthTexture, uv);
}

inline float SampleZBuffer(float2 uv, int2 offset)
{
    return _CameraDepthTexture.Sample(sampler_CameraDepthTexture, uv, offset);
}

//
// albedo occlusion buffer
//
inline half4 SampleGBuffer0(float2 uv)
{
    return _CameraGBufferTexture0.Sample(sampler_CameraGBufferTexture0, uv);
}

inline half4 SampleGBuffer0(float2 uv, int2 offset)
{
    return _CameraGBufferTexture0.Sample(sampler_CameraGBufferTexture0, uv, offset);
}

//
// specular roughness buffer
//
inline half4 SampleGBuffer1(float2 uv)
{
    return _CameraGBufferTexture1.Sample(sampler_CameraGBufferTexture1, uv);
}

inline half4 SampleGBuffer1(float2 uv, int2 offset)
{
    return _CameraGBufferTexture1.Sample(sampler_CameraGBufferTexture1, uv, offset);
}

//
// normal buffer
//
inline half4 SampleGBuffer2(float2 uv)
{
    return _CameraGBufferTexture2.Sample(sampler_CameraGBufferTexture2, uv);
}

inline half4 SampleGBuffer2(float2 uv, int2 offset)
{
    return _CameraGBufferTexture2.Sample(sampler_CameraGBufferTexture2, uv, offset);
}

//
// light buffer
//
inline half4 SampleGBuffer3(float2 uv)
{
    return _CameraGBufferTexture3.Sample(sampler_CameraGBufferTexture3, uv);
}

inline half4 SampleGBuffer3(float2 uv, int2 offset)
{
    return _CameraGBufferTexture3.Sample(sampler_CameraGBufferTexture3, uv, offset);
}

//
// ao buffer
//
inline half4 SampleAO(float2 uv)
{
    return _SSGITemporalAOBuffer.Sample(sampler_SSGITemporalAOBuffer, uv);
}

inline half4 SampleAO(float2 uv, int2 offset)
{
    return _SSGITemporalAOBuffer.Sample(sampler_SSGITemporalAOBuffer, uv, offset);
}

// gi buffer
inline half4 SampleGI(float2 uv)
{
    return _SSGITemporalGIBuffer.Sample(sampler_SSGITemporalGIBuffer, uv);
}

inline half4 SampleGI(float2 uv, int2 offset)
{
    return _SSGITemporalGIBuffer.Sample(sampler_SSGITemporalGIBuffer, uv, offset);
}

inline void SampleCoordinates(float2 uv, out float4 vpos, out float4 wpos, out float depth)
{
    float4 spos = float4(uv * 2.0h - 1.0h, 1.0h, 1.0h);
    spos = mul(_ClipToViewMatrix, spos);
    spos = spos / spos.w;

    // sample depth first
    depth = SampleZBuffer(uv);
    float vdepth = Linear01Depth(depth);
    depth = LinearEyeDepth(depth);
    // view space
    vpos = float4(spos.xyz * vdepth, 1.0f);
    // world space
    wpos = mul(_ViewToWorldMatrix, vpos);
}

inline float2 GetAccumulationUv(float4 wpos)
{
    float4 vpos = mul(_PrevWorldToViewMatrix, wpos);
    float4 spos = mul(_PrevViewToClipMatrix, vpos);
    return mad(spos.xy / spos.w, 0.5h, 0.5h);
}

inline float4 GetAccumulationPos(float2 uv)
{
    float4 spos = float4(uv * 2.0f - 1.0f, 1.0f, 1.0f);
    spos = mul(_PrevClipToViewMatrix, spos);
    spos = spos / spos.w;

    float depth = Linear01Depth(SampleZBuffer(uv));
    float4 vpos = float4(spos.xyz * depth, 1.0f);
    return mul(_PrevViewToWorldMatrix, vpos);
}

/*
inline float GradientNoise(float2 uv)
{
    uv = uv + frac(_Time.xx);
    float3 hash = frac(uv.xyx * 10.311f);
    hash += dot(hash, hash.yzx + 33.33f);
    return frac((hash.x + hash.y) * hash.z);
}
*/

inline float GradientNoise(float2 uv)
{
    uv = uv + frac(_Time.xx);
    return frac(sin(dot(uv, float2(12.9898f, 78.2333f))) * 43758.5453123f);
}

inline float FastSqrt(float x)
{
    return asfloat(0x1fbd1df5 + (asint(x) >> 1));
}

inline float2 FastSqrt(float2 x)
{
    return asfloat(0x1fbd1df5 + (asint(x) >> 1));
}

inline float3 FastSqrt(float3 x)
{
    return asfloat(0x1fbd1df5 + (asint(x) >> 1));
}

inline float4 FastSqrt(float4 x)
{
    return asfloat(0x1fbd1df5 + (asint(x) >> 1));
}

float FastArcCos(float x)
{
    float y = abs(x);
    float res = -0.156583f * y + HALF_PI;
    res *= FastSqrt(1.0f - y);
    return (x >= 0) ? res : FULL_PI - res;
}

float2 FastArcCos(float2 x)
{
    float2 y = abs(x);
    float2 res = -0.156583f * y + HALF_PI;
    res *= FastSqrt(1.0f - y);
    return (x >= 0) ? res : FULL_PI - res;
}

float3 FastArcCos(float3 x)
{
    float3 y = abs(x);
    float3 res = -0.156583f * y + HALF_PI;
    res *= FastSqrt(1.0f - y);
    return (x >= 0) ? res : FULL_PI - res;
}

float4 FastArcCos(float4 x)
{
    float4 y = abs(x);
    float4 res = -0.156583f * y + HALF_PI;
    res *= FastSqrt(1.0f - y);
    return (x >= 0) ? res : FULL_PI - res;
}

float FastArcTanPos(float x)
{
    float t0 = (x < 1.0f) ? x : 1.0f / x;
    float t1 = t0 * t0;
    float poly = 0.0872929f;
    poly = -0.301895f + poly * t1;
    poly = 1.0f + poly * t1;
    poly = poly * t0;
    return (x < 1.0f) ? poly : HALF_PI - poly;
}

float FastArcTan(float x)
{
    float t0 = FastArcTanPos(abs(x));
    return (x < 0.0f) ? -t0 : t0;
}

float2 FastArcTanPos(float2 x)
{
    float2 t0 = (x < 1.0f) ? x : 1.0f / x;
    float2 t1 = t0 * t0;
    float2 poly = 0.0872929f;
    poly = -0.301895f + poly * t1;
    poly = 1.0f + poly * t1;
    poly = poly * t0;
    return (x < 1.0f) ? poly : HALF_PI - poly;
}

float2 FastArcTan(float2 x)
{
    float2 t0 = FastArcTanPos(abs(x));
    return (x < 0.0f) ? -t0 : t0;
}

float3 FastArcTanPos(float3 x)
{
    float3 t0 = (x < 1.0f) ? x : 1.0f / x;
    float3 t1 = t0 * t0;
    float3 poly = 0.0872929f;
    poly = -0.301895f + poly * t1;
    poly = 1.0f + poly * t1;
    poly = poly * t0;
    return (x < 1.0f) ? poly : HALF_PI - poly;
}

float3 FastArcTan(float3 x)
{
    float3 t0 = FastArcTanPos(abs(x));
    return (x < 0.0f) ? -t0 : t0;
}

float4 FastArcTanPos(float4 x)
{
    float4 t0 = (x < 1.0f) ? x : 1.0f / x;
    float4 t1 = t0 * t0;
    float4 poly = 0.0872929f;
    poly = -0.301895f + poly * t1;
    poly = 1.0f + poly * t1;
    poly = poly * t0;
    return (x < 1.0f) ? poly : HALF_PI - poly;
}

float4 FastArcTan(float4 x)
{
    float4 t0 = FastArcTanPos(abs(x));
    return (x < 0.0f) ? -t0 : t0;
}

inline float2 EncodeInterleavedUV(float2 uv, float4 res, uint2 split)
{
    uint4 pixel = uint4(uv * res.zw, res.zw);
    return ((pixel.xy * split) % pixel.zw + (pixel.xy * split) / pixel.zw + 0.5f) * res.xy;
}

inline float2 DecodeInterleavedUV(float2 uv, float4 res, uint2 split)
{
    uint4 pixel = uint4(uv * res.zw, res.zw);
    return ((pixel.xy * split) % pixel.zw + (pixel.xy * split) / pixel.zw + 0.5f) * res.xy;
}

inline float2 GetStochasticUV(float2 uv, float4 res, uint2 split)
{
    uint4 pixel = uint4(uv * res.zw, res.zw);
    return (pixel / split + 0.5f) * res.xy * split;
}

#endif