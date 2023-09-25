#ifndef POSTFX_COMMON_CGINC
#define POSTFX_COMMON_CGINC

#include "UnityCG.cginc"

#define NUM_TAPS 11

const static float4 blurKernel[NUM_TAPS] = {
    {0.56047900f, 0.66908600f, 0.78472800f,  0.00f},
    {0.00471691f, 0.00018477f, 0.00005076f, -2.00f},
    {0.01928310f, 0.00282018f, 0.00084214f, -1.28f},
    {0.03639000f, 0.01309990f, 0.00643685f, -0.72f},
    {0.08219040f, 0.03586080f, 0.02092610f, -0.32f},
    {0.07718020f, 0.11349100f, 0.07938030f, -0.08f},
    {0.07718020f, 0.11349100f, 0.07938030f,  0.08f},
    {0.08219040f, 0.03586080f, 0.02092610f,  0.32f},
    {0.03639000f, 0.01309990f, 0.00643685f,  0.72f},
    {0.01928310f, 0.00282018f, 0.00084214f,  1.28f},
    {0.00471691f, 0.00018477f, 0.00005076f,  2.00f},
};

uniform sampler2D _MainTex;
uniform sampler2D _SkinJitter;

uniform sampler2D _CameraDepthTexture;
uniform sampler2D _CameraGBufferTexture2;

uniform float4 _MainTex_TexelSize;
uniform float4 _SkinJitter_TexelSize;

uniform float4x4 _WorldToViewMatrix;
uniform float4x4 _ViewToWorldMatrix;

uniform float4x4 _ViewToClipMatrix;
uniform float4x4 _ClipToViewMatrix;

uniform half2 _DeferredBlurredNormalsParams;

inline half4 SampleTexel(float2 uv)
{
    return tex2D(_MainTex, uv);
}

inline half4 SampleGBuffer2(float2 uv)
{
    return tex2D(_CameraGBufferTexture2, uv);
}

inline float SampleZBuffer(float2 uv)
{
    return tex2D(_CameraDepthTexture, uv);
}

inline void SampleCoordinates(float2 uv, out float4 vpos, out float depth)
{
    float4 spos = float4(uv * 2.0h - 1.0h, 1.0h, 1.0h);
    spos = mul(_ClipToViewMatrix, spos);
    spos = spos / spos.w;

    depth = SampleZBuffer(uv);
    vpos = float4(spos.xyz * Linear01Depth(depth), 1.0f);

    depth = LinearEyeDepth(depth);
}

inline half3 SampleViewNormal(float2 uv)
{
    half3 vnrm = SampleGBuffer2(uv);
    vnrm = normalize(mad(vnrm, 2.0h, -1.0h));
    return mul(_WorldToViewMatrix, vnrm);
}

inline float3 SampleDirection(float3 vnrm, float2 direction)
{
    float3 dir = float3(direction, 0.0f) - vnrm * dot(float3(direction, 0.0f), vnrm);
    return normalize(dir) * _DeferredBlurredNormalsParams.x * 0.001f;
}

half4 DiffuseBlur(v2f_img IN, float2 direction)
{
    half4 colorM = tex2D(_MainTex, IN.uv);

    if (colorM.w < 1.0h)
    {
        return half4(colorM.xyz, 0.0h);
    }

    else
    {
        float4 vpos;
        float depth;

        SampleCoordinates(IN.uv, vpos, depth);

        half3 vnrm = SampleViewNormal(IN.uv);
        float3 dir = SampleDirection(vnrm, direction);

        half3 sum = colorM.xyz * blurKernel[0].xyz;
        half3 norm = blurKernel[0].xyz;
        
        [unroll]
        for (uint i = 1; i < NUM_TAPS; i ++)
        {
            float4 vp = float4(mad(dir, blurKernel[i].w, vpos.xyz), 1.0f);
            float4 sp = mul(unity_CameraProjection, vp);
            float2 uv = sp.xy / sp.w * 0.5f + 0.5f;

            half4 colorSample = SampleTexel(uv);
            float depthSample = LinearEyeDepth(SampleZBuffer(uv));

            // depth-aware
            half zCorr = exp(-_DeferredBlurredNormalsParams.y * abs(vp.z + depthSample));
            // mask-aware
            half mCorr = step(1.0h, colorSample.w);

            sum += colorSample.xyz * blurKernel[i].xyz * zCorr * mCorr;
            norm += blurKernel[i].xyz * zCorr * mCorr;
        }

        return half4(sum / norm, 1.0h);
    }
}

fixed4 NormalBlur(v2f_img IN, float2 direction)
{
    fixed4 normalM = tex2D(_MainTex, IN.uv);

    if (normalM.w > 0.0h)
    {
        return normalM;
    }

    else
    {
        normalM.xyz = normalize(mad(normalM.xyz, 2.0h, -1.0h));

        float4 vpos;
        float depth;

        SampleCoordinates(IN.uv, vpos, depth);

        half3 vnrm = SampleViewNormal(IN.uv);
        float3 dir = SampleDirection(vnrm, direction);

        half3 sum = normalM.xyz * blurKernel[0].x;
        half norm = blurKernel[0].x;

        [unroll]
        for (uint i = 1; i < NUM_TAPS; i ++)
        {
            float4 vp = float4(mad(dir, blurKernel[i].w, vpos.xyz), 1.0f);
            float4 sp = mul(unity_CameraProjection, vp);
            float2 uv = sp.xy / sp.w * 0.5f + 0.5f;

            half4 normalSample = SampleTexel(uv);
            float depthSample = LinearEyeDepth(SampleZBuffer(uv));
            normalSample.xyz = normalize(mad(normalSample.xyz, 2.0h, -1.0h));

            // depth-aware
            half zCorr = exp(-_DeferredBlurredNormalsParams.y * abs(vp.z + depthSample));
            // mask-aware
            half mCorr = step(normalSample.w, 0.1h);

            sum += normalSample.xyz * blurKernel[i].x * zCorr * mCorr;
            norm += blurKernel[i].x * zCorr * mCorr;
        }

        sum = normalize(sum / norm);
        sum = mad(sum, 0.5h, 0.5h);

        return fixed4(sum, normalM.w);
    }
}

inline half2 RandomAxis(v2f_img IN)
{
    return tex2D(_SkinJitter, IN.uv * _ScreenParams.xy * _SkinJitter_TexelSize.xy).xy;
}

#endif