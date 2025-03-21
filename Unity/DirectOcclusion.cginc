#ifndef HSSSS_DIRECTOCCLUSION_CGINC
#define HSSSS_DIRECTOCCLUSION_CGINC

#include "Assets/HSSSS/Framework/AreaLight.cginc"

#define FULL_PI 3.14159265359f
#define HALF_PI 1.57079632679f

uniform uint _UseDirectOcclusion;
uniform half _SSDOLightApatureScale;
uniform sampler2D _SSAOMaskRenderTexture;

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

inline void ComputeDirectOcclusion(float3 wpos, float3 ldir, float2 uv, inout half2 shadow)
{
#if defined(SHADOWS_CUBE) || defined(SHADOWS_DEPTH) || defined(SHADOWS_SCREEN)
    if (_UseDirectOcclusion > 0)
    {
        half4 ao = tex2D(_SSAOMaskRenderTexture, uv);
        // bent normal
        ao.xyz = normalize(mad(ao.xyz, 2.0h, -1.0h));

        half4 angle;

        // light apature
        angle.x = FastArcTan(_SSDOLightApatureScale);
        // occlusion apature
        angle.y = FastArcCos(sqrt(1.0h - ao.w));
        // absolute angle difference
        angle.z = abs(angle.x - angle.y);
        // angle between bentnormal and reflection vector
        angle.w = FastArcCos(dot(ao.xyz, normalize(ldir)));

        half intersection = smoothstep(0.0h, 1.0h, 1.0h - saturate((angle.w - angle.z) / (angle.x + angle.y - angle.z)));
        half occlusion = lerp(0.0h, intersection, saturate((angle.y - 0.1h) * 5.0h));

        shadow.r = min(shadow.r, lerp(occlusion, 1.0h, _LightShadowData.r));
    }
#endif
}

#endif