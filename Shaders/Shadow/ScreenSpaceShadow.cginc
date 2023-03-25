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

half4x4 _WorldToViewMatrix;
half4x4 _ViewToWorldMatrix;

half3 _LightPosition;

sampler2D _MainTex;
sampler2D _CameraDepthTexture;
sampler2D _BackFaceDepthBuffer;
sampler2D _CameraGBufferTexture2;

sampler2D _ShadowJitterTexture;

float4 _MainTex_TexelSize;
float4 _ShadowJitterTexture_TexelSize;

#define NUM_TAPS 7

const static half2 blurKernel[NUM_TAPS] =
{
    {0.2148h,  0.0h},
    {0.0713h, -3.0h},
    {0.1315h, -2.0h},
    {0.1898h, -1.0h},
    {0.0713h,  3.0h},
    {0.1315h,  2.0h},
    {0.1898h,  1.0h}
};

#define _SSCSNumStride 32

half _SSCSRayLength;
half _SSCSRayRadius;
half _SSCSMeanDepth;
half _SSCSDepthBias;

struct ray
{
    half4 pos;
    half4 dir;
    half2 uv;
    half len;
    bool hit;
};

inline half GradientNoise(half2 uv)
{
    return frac(sin(dot(uv, half2(12.9898, 78.2333))) * 43758.5453123);
}

inline half3x3 GramSchmidtMatrix(half2 uv, half3 axis)
{
    half3 jitter = tex2D(_ShadowJitterTexture,
        uv * _ScreenParams.xy * _ShadowJitterTexture_TexelSize.xy + _Time.yy);

    jitter = normalize(mad(jitter, 2.0f, -1.0f));

    half3 tangent = normalize(jitter - axis * dot(jitter, axis));
    half3 bitangent = normalize(cross(axis, tangent));

    return half3x3(tangent, bitangent, axis);
}

// view-space ray tracing
inline half RayTraceLoop(inout ray ray)
{
    half4 vpos = mul(_WorldToViewMatrix, ray.pos);
    half4 vdir = mul(_WorldToViewMatrix, ray.dir);

    ray.len = mad(vdir.z, ray.len, vpos.z) > _ProjectionParams.y ?
        -(vpos.z + _ProjectionParams.z) / vdir.z : ray.len;

    [unroll]
    for (uint iter = 0; iter < _SSCSNumStride && ray.hit == false; iter ++)
    {
        half step = ((half)_SSCSNumStride - iter) * ray.len / _SSCSNumStride;

        half4 vp = mad(vdir, step, vpos);//vpos + vdir * ray.len * step;
        half4 sp = mul(unity_CameraProjection, vp);

        ray.uv = sp.xy / sp.w * 0.5f + 0.5f;

        half zRay = -vp.z;
        half zFace = LinearEyeDepth(tex2D(_CameraDepthTexture, ray.uv));
        half zBack = max(tex2D(_BackFaceDepthBuffer, ray.uv), zFace + 0.1h);

        if (zRay > zFace && zRay < zBack)
        {
            ray.hit = true;
            return 0.0h;
        }
    }

    return 1.0h;
}

half SampleShadowMap(v2f i)
{
    half depth = UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, i.uv));
	depth = Linear01Depth(depth);

	half4 vpos = half4(i.ray * depth, 1.0h);
	half4 wpos = mul(_ViewToWorldMatrix, vpos);

    half4 wnrm = half4(tex2D(_CameraGBufferTexture2, i.uv).rgb, 0.0h);
    wnrm.xyz = normalize(mad(wnrm, 2.0h, -1.0h));

    half3 ldir = normalize(_LightPosition - wpos.xyz);
    half3x3 tbn = GramSchmidtMatrix(i.uv, ldir);

    half rayRadius = _SSCSRayRadius * 0.01h;

    ray ray;

    half3 offset = mul(half3(0.25h, 0.0h, 0.0h), tbn);
    ray.hit = false;
    ray.pos = mad(wnrm, 0.001f, wpos);  
    ray.len = _SSCSRayLength * 0.01h;
    ray.dir = half4(normalize(mad(offset, rayRadius, ldir)), 0.0h);
    half shadow = RayTraceLoop(ray);

    offset = mul(half3(0.0h, 0.5h, 0.0h), tbn);
    ray.hit = false;
    ray.pos = mad(wnrm, 0.001f, wpos);  
    ray.len = _SSCSRayLength * 0.01h;
    ray.dir = half4(normalize(mad(offset, rayRadius, ldir)), 0.0h);
    shadow += RayTraceLoop(ray);

    offset = mul(half3(-0.75h, 0.0h, 0.0h), tbn);
    ray.hit = false;
    ray.pos = mad(wnrm, 0.001f, wpos);  
    ray.len = _SSCSRayLength * 0.01h;
    ray.dir = half4(normalize(mad(offset, rayRadius, ldir)), 0.0h);
    shadow += RayTraceLoop(ray);

    offset = mul(half3(0.0h, -1.0h, 0.0h), tbn);
    ray.hit = false;
    ray.pos = mad(wnrm, 0.001f, wpos);  
    ray.len = _SSCSRayLength * 0.01h;
    ray.dir = half4(normalize(mad(offset, rayRadius, ldir)), 0.0h);
    shadow += RayTraceLoop(ray);

    return shadow / 4;
}

half BlurInDir(half2 uv, half2 dir)
{
    half shadowM = tex2D(_MainTex, uv);
    half depthM = LinearEyeDepth(tex2D(_CameraDepthTexture, uv));

    half2 step = _MainTex_TexelSize.xy * dir * 1.0h;

    half shadowB = shadowM * blurKernel[0].x;

    [unroll]
    for (int i = 1; i < NUM_TAPS; i ++)
    {
        half2 offsetUv = mad(step, blurKernel[i].y, uv);
        half shadow = tex2D(_MainTex, offsetUv);

        half depth = LinearEyeDepth(tex2D(_CameraDepthTexture, offsetUv));
        half s = min(1.0h, 100.0h * abs(depth - depthM));

        shadowB += lerp(shadow, shadowM, s) * blurKernel[i].x;
    }

    return shadowB;
}

#endif