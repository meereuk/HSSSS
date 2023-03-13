#ifndef HSSSS_SSRT_CGINC
#define HSSSS_SSRT_CGINC

#include "UnityCG.cginc"

// vertex input
struct appdata
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
};

// fragment input
struct v2f
{
    float2 uv : TEXCOORD0;
    float4 vertex : SV_POSITION;
};

//ray information
struct ray
{
    bool hit;
    float3 dir;
    float3 len;
    float2 uv;
};

// vertex shader
v2f vert (appdata v)
{
    v2f o;
    o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
    o.uv = v.uv;
    return o;
}

sampler2D _MainTex;
// albedo and occlusion
sampler2D _CameraGBufferTexture0;
// specular and roughness
sampler2D _CameraGBufferTexture1;
// world space normal
sampler2D _CameraGBufferTexture2;
// depth
sampler2D _CameraDepthTexture;

float4x4 _MATRIX_V;
float4x4 _MATRIX_P;
float4x4 _MATRIX_VP;

float4x4 _MATRIX_IV;
float4x4 _MATRIX_IP;
float4x4 _MATRIX_IVP;

/*
inline float ComputeLinearDepth(float2 uv)
{
    return LinearEyeDepth(tex2D(_CameraDepthTexture, uv));
}

inline float4 ComputePositionScreen(float2 uv)
{
    float depth = tex2D(_CameraDepthTexture, uv);
    return float4(mad(uv, 2.0f, -1.0f), depth, 1.0f);
}
*/

inline float4 ComputePositionWorld(float2 uv)
{
    float depth = tex2D(_CameraDepthTexture, uv);
    float4 spos = float4(mad(uv, 2.0f, -1.0f), depth, 1.0f);
    float4 wpos = mul(_MATRIX_IVP, spos);
    return float4(wpos.xyz / wpos.w, 1.0f);
}

/*
inline float3 ComputePositionView(float3 spos)
{
    float4 vpos = mul(_MATRIX_IP, float4(spos, 1.0f));
    return vpos.xyz / vpos.w;
}
*/

inline float3 SampleAlbedo(float2 uv)
{
    return tex2D(_CameraGBufferTexture0, uv).rgb;
}

inline float3 SampleNormal(float2 uv)
{
    return normalize(mad(tex2D(_CameraGBufferTexture2, uv).rgb, 2.0f, -1.0f));
}

inline float3 SampleLight(float2 uv)
{
    return tex2D(_MainTex, uv).rgb;
}

/*
inline float3 ComputeNormalView(float3 wnrm)
{
    return normalize(mul(_MATRIX_V, float4(wnrm, 0.0f)).rgb);
}
*/

#define NUM_STEP 8
#define NUM_RAYS 64
#define RAY_DIST 2.0

inline void RayTraceIteration(float3 pos, inout ray ray)
{
    float3 stride = ray.dir * RAY_DIST / NUM_STEP;

    [unroll]
    for (uint iter = 1; iter <= NUM_STEP; iter ++)
    {
        float4 wpos = float4(pos + stride * iter, 1.0f);

        float4 vpos = mul(_MATRIX_V, wpos);
        float4 cpos = mul(_MATRIX_VP, wpos);

        float2 uv = mad(cpos.xy / cpos.w, 0.5f, 0.5f);

        float rayDepth = -vpos.z;
        float refDepth = LinearEyeDepth(tex2D(_CameraDepthTexture, uv));

        float zDiff = rayDepth - refDepth;

        if (zDiff > 0.0f && zDiff < 0.5f)
        {
            ray.hit = true;
            ray.len = dot(stride * iter, stride * iter);
            ray.uv = uv;
            return;
        }
    }
}


inline half3 ComputeIndirectLight(float2 uv)
{
    half3 albedo = SampleAlbedo(uv);
    half3 normal = SampleNormal(uv);
    half3 wcoord = ComputePositionWorld(uv);

    half3 rotationX = normalize(cross(normal, normal.zxy));
    half3 rotationY = normalize(cross(normal, rotationX));

    half3 indirect = 0.0h;

    half jitter = frac(sin(dot(uv, half2(12.9898, 78.233)))* 43758.5453123);

    for(uint iter = 0; iter < NUM_RAYS; iter ++)
    {
        half t = 2.4 * half(iter) + jitter;
        half r = sqrt(half(iter) + 0.5h) / sqrt(half(NUM_RAYS));
        half2 disk = r * half2(cos(t), sin(t));

        half3 offset = rotationX * disk.x + rotationY * disk.y;

        ray ray;

        ray.hit = false;
        ray.dir = normalize(normal + offset);
        ray.len = 1.0h;
        ray.uv = uv;

        RayTraceIteration(wcoord, ray);

        if (ray.hit)
        {
            half3 light = SampleLight(ray.uv);
            half3 refNormal = SampleNormal(ray.uv);
            
            half ndotn = step(dot(ray.dir, refNormal), 0.0h);
            half ndotl = clamp(dot(ray.dir, normal), 0.0h, 1.0h);
            half atten = exp(-2.0h * sqrt(ray.len));


            indirect += ndotn * ndotl * atten * light * albedo;
        }
    }

    return indirect / NUM_RAYS;
}

#endif