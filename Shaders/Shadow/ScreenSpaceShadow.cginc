#ifndef HSSSS_SCREENSPACESHADOW_CGINC
#define HSSSS_SCREENSPACESHADOW_CGINC

#include "UnityCG.cginc"

struct appdata
{
    half4 vertex : POSITION;
    half2 uv : TEXCOORD0;
};

struct v2f
{
    half4 vertex : SV_POSITION;
    half2 uv : TEXCOORD0;
    half3 ray : TEXCOORD1;
};

v2f vert (appdata v)
{
    v2f o;
    o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
    o.uv = v.uv;
    half4 ray = half4(v.uv * 2.0h - 1.0h, 1.0h, 1.0h);
    ray = mul(unity_CameraInvProjection, ray);
    o.ray = ray / ray.w;
    return o;
}

half4x4 _MATRIX_V;
half4x4 _MATRIX_P;
half4x4 _MATRIX_VP;

half4x4 _MATRIX_IV;
half4x4 _MATRIX_IP;
half4x4 _MATRIX_IVP;

half3 _LightPosition;

sampler2D _MainTex;
sampler2D _CameraDepthTexture;
sampler2D _CameraGBufferTexture2;

half _SSCSRayLength;
half _SSCSMeanDepth;
half _SSCSDepthBias;

// view-space ray tracing
inline half RayTraceLoop(half4 pos, half4 dir)
{
    half rayLength = _SSCSRayLength * 0.01h;
    half meanDepth = _SSCSMeanDepth * 0.01h;
    half depthBias = _SSCSDepthBias * 0.01h;

    half4 V0 = mul(_MATRIX_V, pos);
    half4 VD = mul(_MATRIX_V, dir);

    half len = mad(VD.z, rayLength, V0.z) > _ProjectionParams.y ? -(V0.z + _ProjectionParams.z) / VD.z : rayLength;

    [unroll]
    for (uint iter = 0; iter < 64; iter ++)
    {
        half step = (64.0f - iter) / 64.0f;

        half4 vpos = V0 + VD * len * step;
        half4 spos = mul(_MATRIX_P, vpos);

        half2 uv = spos.xy / spos.w * 0.5f + 0.5f;

        half zDiff = -vpos.z - LinearEyeDepth(tex2D(_CameraDepthTexture, uv));

        if (zDiff > depthBias && zDiff < meanDepth)// && -vpos.z < (z + 0.5f))
        {
            return 0.0h;
        }
    }

    return 1.0h;
}

half SampleShadowMap(v2f i)
{
    half depth = UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, i.uv));
	depth = Linear01Depth(depth);

	half4 vpos = half4(i.ray * depth, 1.0f);
	half4 wpos = mul(_MATRIX_IV, vpos);

    half4 wnrm = half4(tex2D(_CameraGBufferTexture2, i.uv).rgb * 2.0h - 1.0h, 0.0h);
    half4 wdir = half4(normalize(_LightPosition - wpos.xyz), 0.0f);

    return RayTraceLoop(wpos + 0.001f * wnrm, wdir);

    /*
    half3 jitter = float3(
        frac(sin(dot(i.uv + _Time.xx, 1.0f * float2(12.9898, 78.233))) * 43758.5453123),
        frac(sin(dot(i.uv + _Time.yy, 2.0f * float2(12.9898, 78.233))) * 43758.5453123),
        frac(sin(dot(i.uv + _Time.zz, 3.0f * float2(12.9898, 78.233))) * 43758.5453123)
    );

    jitter = normalize(mad(jitter, 2.0f, -1.0f));

    half3 tangent = normalize(jitter - wdir.xyz * dot(jitter, wdir.xyz));
    half3 bitangent = normalize(cross(wdir.xyz, tangent));

    half3x3 tbn = half3x3(tangent, bitangent, wdir.xyz);

    half3 offset = mul(half3(1.0h, 0.0h, 0.0h), tbn);
    wdir.xyz = normalize(mad(offset, 0.01h, wdir.xyz));
    */
}

half BlurInDir(v2f i, float2 dir)
{
    half shadow = 0.0h;
    
    for (int iter = -2; iter < 3; iter ++)
    {
        float2 offset = dir * 0.0001f * iter;

        shadow += tex2D(_MainTex, i.uv + offset).x;
    }

    return shadow / 5.0h;
}

#endif