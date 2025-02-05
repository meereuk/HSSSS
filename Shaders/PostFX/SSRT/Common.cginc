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

uniform Texture2D _SSGITemporalGIBuffer;
uniform SamplerState sampler_SSGITemporalGIBuffer;

uniform Texture3D _BlueNoise;
uniform SamplerState sampler_BlueNoise;

uniform float4x4 _WorldToViewMatrix;
uniform float4x4 _ViewToWorldMatrix;

uniform float4x4 _ViewToClipMatrix;
uniform float4x4 _ClipToViewMatrix;

uniform float4x4 _PrevWorldToViewMatrix;
uniform float4x4 _PrevViewToWorldMatrix;

uniform float4x4 _PrevViewToClipMatrix;
uniform float4x4 _PrevClipToViewMatrix;

uniform uint _FrameCount;

#define FULL_PI 3.14159265359f
#define HALF_PI 1.57079632679f
#define HF_PI   1.57079632679f
#define QR_PI   0.78539816339f

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
// noise
//
inline float3 SampleNoise(float2 uv)
{
    float z = (float)(_FrameCount % 16) * 0.015625f + 0.0078125f;
    return _BlueNoise.Sample(sampler_BlueNoise, float3(uv * _ScreenParams.xy * 0.0078125f, z));
}

//
// recunstruct position from z-buffer
//
inline void SampleCoordinates(float2 uv, out float4 vpos, out float4 wpos, out float depth)
{
    // sample depth first
    depth = SampleZBuffer(uv);
    float vdepth = Linear01Depth(depth);
    depth = LinearEyeDepth(depth);
    // screen-space position
    float4 spos = float4(mad(uv, 2.0f, -1.0f), 1.0f, 1.0h);
    // view-space position
    vpos = mul(_ClipToViewMatrix, spos);
    vpos = float4(vpos.xyz * vdepth / vpos.w, 1.0f);
    // world space
    wpos = mul(_ViewToWorldMatrix, vpos);
}

//
// calculating reference uv difference for 1 meter
//
inline float2 GetReferenceUvDiff(float4 vpos, float2 uv)
{
    float4 vp, sp;
    float2 uvref;

    vp = float4(1.0f, 0.0f, 0.0f, 0.0f) + vpos;
    sp = mul(unity_CameraProjection, vp);
    uvref.x = sp.x / sp.w * 0.5f + 0.5f - uv.x;

    vp = float4(0.0f, 1.0f, 0.0f, 0.0f) + vpos;
    sp = mul(unity_CameraProjection, vp);
    uvref.y = sp.y / sp.w * 0.5f + 0.5f - uv.y;

    return uvref;
}

//
// gram-schmidt process
//
inline float3x3 GramSchmidtMatrix(float2 uv, float3 axis)
{
    float3 jitter = normalize(mad(SampleNoise(uv), 2.0f, -1.0f));
    float3 tangent = normalize(jitter - axis * dot(jitter, axis));
    float3 bitangent = normalize(cross(axis, tangent));

    return float3x3(tangent, bitangent, axis);
}

//
// poisson disk sampling
//
inline float3 PoissonDisk(uint i, uint N)
{
	float t = 2.4f * i;
	float r = sqrt((i + 0.5f) / N);
	return float3(r * cos(t), r * sin(t), r);
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

    half3 color = c[4];

    half3 temp;

    mnmx6(c[0], c[1], c[2], c[3], c[4], c[5]);
    mnmx5(c[1], c[2], c[3], c[4], c[6]);
    mnmx4(c[2], c[3], c[4], c[7]);
    mnmx3(c[3], c[4], c[8]);

    return half4(clamp(color, c[2], c[6]), 1.0h);
}

float Hash(float x)
{
    x = frac(x * 0.1031f);
    x *= x + 33.33f;
    x *= x + x;
    return frac(x);
}

#endif