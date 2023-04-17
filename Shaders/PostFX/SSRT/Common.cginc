#ifndef HSSSS_SSRT_CGINC
#define HSSSS_SSRT_CGINC

#include "UnityCG.cginc"

uniform sampler2D _MainTex;
uniform sampler2D _CameraDepthTexture;
uniform sampler2D _CameraGBufferTexture0;
uniform sampler2D _CameraGBufferTexture2;
uniform sampler2D _CameraGBufferTexture3;

uniform float4 _MainTex_TexelSize;

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

#define KERNEL_TAPS 9

const static half2 blurKernel[KERNEL_TAPS] =
{
    {-4.0h, 0.0285h},
    {-3.0h, 0.0672h},
    {-2.0h, 0.1241h},
    {-1.0h, 0.1790h},
    { 0.0h, 0.2024h},
    { 1.0h, 0.1790h},
    { 2.0h, 0.1241h},
    { 3.0h, 0.0672h},
    { 4.0h, 0.0285h}
};

struct ray
{
    float2 org;
    float2 fwd;
    float2 bwd;
    float len;
    float z;
};

inline void SampleCoordinates(v2f_img IN, out float4 vpos, out float4 wpos, out float depth)
{
    float4 spos = float4(IN.uv * 2.0h - 1.0h, 1.0h, 1.0h);
    spos = mul(_ClipToViewMatrix, spos);
    spos = spos / spos.w;

    // sample depth first
    depth = tex2D(_CameraDepthTexture, IN.uv);
    float vdepth = Linear01Depth(depth);
    depth = LinearEyeDepth(depth);
    // view space
    vpos = float4(spos.xyz * vdepth, 1.0h);
    // world space
    wpos = mul(_ViewToWorldMatrix, vpos);
}

inline float2 GetAccumulationUv(float4 wpos)
{
    float4 vpos = mul(_PrevWorldToViewMatrix, wpos);
    float4 spos = mul(_PrevViewToClipMatrix, vpos);
    return mad(spos.xy / spos.w, 0.5h, 0.5h);
}

inline float GradientNoise(float2 uv)
{
    return frac(sin(dot(uv, float2(12.9898f, 78.2333f))) * 43758.5453123f);
}

#endif