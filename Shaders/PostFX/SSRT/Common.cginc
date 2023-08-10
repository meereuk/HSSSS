#ifndef HSSSS_SSRT_CGINC
#define HSSSS_SSRT_CGINC

#include "UnityCG.cginc"

struct appdata_mrt
{
    float4 pos: POSITION;
};

struct v2f_mrt
{
    float4 cpos: SV_POSITION;
    float2 uv: TEXCOORD0;
};

v2f_mrt vert_mrt(appdata_mrt v)
{
    v2f_mrt o;
    o.cpos = float4(v.pos.xy, 0.0, 1.0);
    o.uv = v.pos.xy * 0.5f + 0.5f;
    o.uv.y = _ProjectionParams.x < 0.0f ? 1.0f - o.uv.y : o.uv.y;
    return o;
}

uniform Texture2D _MainTex;
uniform SamplerState sampler_MainTex;
uniform float4 _MainTex_TexelSize;

uniform Texture2D _CameraDepthTexture;
uniform SamplerState sampler_CameraDepthTexture;

uniform Texture2D _CameraDepthHistory;
uniform SamplerState sampler_CameraDepthHistory;

uniform Texture2D _CameraGBufferTexture0;
uniform SamplerState sampler_CameraGBufferTexture0;

uniform Texture2D _CameraGBufferTexture1;
uniform SamplerState sampler_CameraGBufferTexture1;

uniform Texture2D _CameraGBufferTexture2;
uniform SamplerState sampler_CameraGBufferTexture2;

uniform Texture2D _CameraGBufferTexture3;
uniform SamplerState sampler_CameraGBufferTexture3;

uniform Texture2D _SSGITemporalGIBuffer;
uniform SamplerState sampler_SSGITemporalGIBuffer;

uniform Texture2D _BlueNoise;
uniform SamplerState sampler_BlueNoise;
uniform float4 _BlueNoise_TexelSize;

uniform float4x4 _WorldToViewMatrix;
uniform float4x4 _ViewToWorldMatrix;

uniform float4x4 _ViewToClipMatrix;
uniform float4x4 _ClipToViewMatrix;

uniform float4x4 _PrevWorldToViewMatrix;
uniform float4x4 _PrevViewToWorldMatrix;

uniform float4x4 _PrevViewToClipMatrix;
uniform float4x4 _PrevClipToViewMatrix;

uniform uint _FrameCount;

static const float bayer2x2[4] =
{
    0.0 , 0.5 ,
    0.75, 0.25
};

static const float bayer4x4[16] =
{
    0.    , 0.5   , 0.125 , 0.625 ,
    0.75  , 0.25  , 0.875 , 0.375 ,
    0.1875, 0.6875, 0.0625, 0.5625,
    0.9375, 0.4375, 0.8125, 0.3125
};

static const float bayer8x8[64] = 
{
    0.      , 0.5     , 0.125   , 0.625   , 0.03125 , 0.53125 , 0.15625 , 0.65625 ,
    0.75    , 0.25    , 0.875   , 0.375   , 0.78125 , 0.28125 , 0.90625 , 0.40625 ,
    0.1875  , 0.6875  , 0.0625  , 0.5625  , 0.21875 , 0.71875 , 0.09375 , 0.59375 ,
    0.9375  , 0.4375  , 0.8125  , 0.3125  , 0.96875 , 0.46875 , 0.84375 , 0.34375 ,
    0.046875, 0.546875, 0.171875, 0.671875, 0.015625, 0.515625, 0.140625, 0.640625,
    0.796875, 0.296875, 0.921875, 0.421875, 0.765625, 0.265625, 0.890625, 0.390625,
    0.234375, 0.734375, 0.109375, 0.609375, 0.203125, 0.703125, 0.078125, 0.578125,
    0.984375, 0.484375, 0.859375, 0.359375, 0.953125, 0.453125, 0.828125, 0.328125
};

#define FULL_PI 3.14159265359f
#define HALF_PI 1.57079632679f

#define s2(a, b)                temp = a; a = min(a, b); b = max(temp, b);
#define mn3(a, b, c)            s2(a, b); s2(a, c);
#define mx3(a, b, c)            s2(b, c); s2(a, c);
#define mnmx3(a, b, c)          mx3(a, b, c); s2(a, b);
#define mnmx4(a, b, c, d)       s2(a, b); s2(c, d); s2(a, c); s2(b, d);
#define mnmx5(a, b, c, d, e)    s2(a, b); s2(c, d); mn3(a, c, e); mx3(b, d, e);
#define mnmx6(a, b, c, d, e, f) s2(a, d); s2(b, e); s2(c, f); mn3(a, b, c); mx3(d, e, f);

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

inline float SampleZHistory(float2 uv)
{
    return _CameraDepthHistory.Sample(sampler_CameraDepthHistory, uv);
}

inline float SampleZHistory(float2 uv, int2 offset)
{
    return _CameraDepthHistory.Sample(sampler_CameraDepthHistory, uv, offset);
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

// gi buffer
inline half4 SampleGI(float2 uv)
{
    return _SSGITemporalGIBuffer.Sample(sampler_SSGITemporalGIBuffer, uv);
}

inline half4 SampleGI(float2 uv, int2 offset)
{
    return _SSGITemporalGIBuffer.Sample(sampler_SSGITemporalGIBuffer, uv, offset);
}

//
// noise
//
inline float3 SampleNoise(float2 uv)
{
    return _BlueNoise.Sample(sampler_BlueNoise, uv * _BlueNoise_TexelSize.xy * _ScreenParams.xy);
}

inline float3 SampleNoise(float2 uv, int2 offset)
{
    return _BlueNoise.Sample(sampler_BlueNoise, uv * _BlueNoise_TexelSize.xy * _ScreenParams.xy, offset);
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

    float depth = Linear01Depth(SampleZHistory(uv));
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
    split = res.zw / split;
    return ((pixel.xy * split) % pixel.zw + (pixel.xy * split) / pixel.zw + 0.5f) * res.xy;
}

inline float2 GetStochasticUV(float2 uv, float4 res, uint2 split)
{
    uint4 pixel = uint4(uv * res.zw, res.zw);
    split = res.zw / split;
    return (pixel / split + 0.5f) * res.xy * split;
}

inline float GetInterleavedIdx(float2 uv, uint split)
{
    uint idx = split * floor(uv.y * split) + floor(uv.x * split);

    if (split == 2)
    {
        return bayer2x2[idx];
    }

    else if (split == 4)
    {
        return bayer4x4[idx];
    }

    else if (split == 8)
    {
        return bayer8x8[idx];
    }

    else
    {
        return 0.0f;
    }

    //return (split * floor(uv.y * split) + floor(uv.x * split)) / (split * split);
}

inline void ClampInterleavedUV(float2 uv, float2 duv, out float2 fwd, out float2 bwd, inout float2 len, uint2 split)
{
    fwd = uv + duv;
    bwd = uv - duv;

    float4 limit = {
        trunc(uv * split) / split + _MainTex_TexelSize.xy,
        (trunc(uv * split) + 1.0f) / split - _MainTex_TexelSize.xy
    };

    float2 fwd_t = clamp(fwd, limit.xy, limit.zw) - uv;
    float2 bwd_t = clamp(bwd, limit.xy, limit.zw) - uv;

    fwd_t = abs(fwd_t / duv);
    bwd_t = abs(bwd_t / duv);

    float2 fac = {
        min(fwd_t.x, fwd_t.y),
        min(bwd_t.x, bwd_t.y)
    };

    fwd =  duv * fac.x;
    bwd = -duv * fac.y;
    len =  len * fac;

/*
    float2 div = {
        length(fwd),
        length(bwd)
    };

    div /= length(duv);

    len *= d

    float div = min(length(fwd), length(bwd)) / length(duv);

    duv *= div;
    len *= div;
    */
}

inline half FadeScreenBoundary(float2 uv)
{
    half4 fade = smoothstep(0.0h, _MainTex_TexelSize.xyxy * 8, float4(uv.xy, 1.0f - uv.xy));
    return fade.x * fade.y * fade.z * fade.w;
}

inline float BlitZBuffer(v2f_img IN) : SV_TARGET
{
    return SampleZBuffer(IN.uv);
}

inline half4 MedianFilter(v2f_img IN) : SV_TARGET
{
    half3 c[9];

    c[0] = SampleTexel(IN.uv, int2(-1, -1));
    c[1] = SampleTexel(IN.uv, int2(-1,  0));
    c[2] = SampleTexel(IN.uv, int2(-1,  1));
    c[3] = SampleTexel(IN.uv, int2( 0, -1));
    c[4] = SampleTexel(IN.uv, int2( 0,  0));
    c[5] = SampleTexel(IN.uv, int2( 0,  1));
    c[6] = SampleTexel(IN.uv, int2( 1, -1));
    c[7] = SampleTexel(IN.uv, int2( 1,  0));
    c[8] = SampleTexel(IN.uv, int2( 1,  1));

    half3 temp;

    mnmx6(c[0], c[1], c[2], c[3], c[4], c[5]);
    mnmx5(c[1], c[2], c[3], c[4], c[6]);
    mnmx4(c[2], c[3], c[4], c[7]);
    mnmx3(c[3], c[4], c[8]);

    return half4(c[7], 1.0h);
}

float Hash(float x)
{
    x = frac(x * 0.1031f);
    x *= x + 33.33f;
    x *= x + x;
    return frac(x);
}

#endif