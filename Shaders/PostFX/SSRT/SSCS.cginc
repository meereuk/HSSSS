#ifndef HSSSS_SSCS_CGINC
#define HSSSS_SSCS_CGINC

#include "Common.cginc"

float3 _LightPosition;

uniform half _SSCSRayLength;
uniform half _SSCSRayStride;
uniform half _SSCSMeanDepth;

#ifndef _SSCSNumStride
    #define _SSCSNumStride 128
#endif

struct ray
{
    float4 org;
    float4 dir;
    float len;
};

half ContactShadow(v2f_img IN) : SV_TARGET
{
    float4 vpos;
    float4 wpos;
    float depth;

    SampleCoordinates(IN.uv, vpos, wpos, depth);

    float4 lpos = mul(_WorldToViewMatrix, float4(_LightPosition, 1.0f));
    float4 vdir = normalize(lpos - vpos);

    float dist = distance(lpos, vpos);
    float len = 1.0f / _SSCSNumStride;

    half shadow = 1.0h;

    [unroll]
    for (float iter = 1.0f; iter <= _SSCSNumStride; iter += 1.0f)
    {
        float4 vp = mad(mad(len, iter, 0.01f), vdir, vpos);
        float4 sp = mul(unity_CameraProjection, vp);
        float2 uv = sp.xy / sp.w * 0.5f + 0.5f;
        float z = LinearEyeDepth(SampleZBuffer(uv));
        float zz = -vp.z;

        float radius = iter * len / dist * 0.1f;

        shadow = min(shadow, smoothstep(zz - radius, zz + radius, z));
    }

    return shadow;

    /*
    float4 dir = normalize(float4(lpos.xy - vpos.xy, 0.0f, 0.0f));

    ray ray;

    ray.z = depth;
    ray.org = IN.uv;
    ray.len = 0.5f;

    float4 spos = mul(unity_CameraProjection, mad(dir, ray.len, vpos));
    ray.fwd = spos.xy / spos.w * 0.5f + 0.5f;

    float theta = -100.0f;

    [unroll]
    for (float iter = 1.0f; iter <= _SSCSNumStride; iter += 1.0f)
    {
        float str = iter / _SSCSNumStride;
        float2 uv = lerp(ray.org, ray.fwd, str);

        float dz = ray.z - LinearEyeDepth(SampleZBuffer(uv));
        dz /= abs(str * ray.len);

        theta = max(theta, dz);
    }

    float ref_theta = (depth + lpos.z) / length(lpos.xy - vpos.xy);

    return smoothstep(theta - 0.01f, theta, ref_theta);
    */
}

#endif