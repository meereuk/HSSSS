#ifndef HSSSS_SSGI_CGINC
#define HSSSS_SSGI_CGINC

#include "Common.cginc"

uniform half _SSGIIntensity;
uniform half _SSGIRayLength;
uniform half _SSGIMeanDepth;
uniform half _SSGIFadeDepth;
uniform half _SSGIMixFactor;
uniform uint _SSGIStepPower;

#ifndef _SSGINumSample
    #define _SSGINumSample 2
#endif

#ifndef _SSGINumStride
    #define _SSGINumStride 4
#endif

#ifndef KERNEL_STEP
    #define KERNEL_STEP 1
#endif

struct ray
{
    // uv
    float2 uv0;
    float2 uv1;
    float2 uv2;

    // view space position
    float4 vp0;
    float4 vp1;
    float4 vp2;

    // view space normal
    half3 nrm;

    // length
    float len;
};

inline half3 HorizonTrace(ray ray)
{
    uint power = max(1, _SSGIStepPower);
    float minStr = length(_ScreenParams.zw - 1.0h) / length(ray.uv1 - ray.uv0);

    float2 theta = -1.0f;
    half3 gi = 0.0h;
    float count = 0.0f;

    [unroll]
    for (float iter = 1.0f; iter <= _SSGINumStride && iter * minStr <= 1.0f; iter += 1.0f)
    {
        float str = iter / _SSGINumStride;
        str = max(iter * minStr, pow(str, power));

        // uv
        float2 uv1 = lerp(ray.uv0, ray.uv1, str);
        float2 uv2 = lerp(ray.uv0, ray.uv2, str);

        // view space position
        float4 vp1 = lerp(ray.vp0, ray.vp1, str);
        float4 vp2 = lerp(ray.vp0, ray.vp2, str);

        // sample illumination
        half4 illum1 = SampleTexel(uv1);
        half4 illum2 = SampleTexel(uv2);

        vp1.z = -illum1.w;
        vp2.z = -illum2.w;

        // horizon calculation
        float2 threshold = ray.len * FastSqrt(1.0f - str * str);

        float2 dz = {
            vp1.z - ray.vp0.z,
            vp2.z - ray.vp0.z
        };

        dz /= abs(str * ray.len);

        // n dot l
        half2 ndotl = {
            saturate(dot(normalize(vp1.xyz - ray.vp0.xyz), ray.nrm)),
            saturate(dot(normalize(vp2.xyz - ray.vp0.xyz), ray.nrm))
        };

        // attenuation
        half2 atten = {
            1.0h / pow(max(distance(vp1.xyz, ray.vp0.xyz), 1.0h), 2),
            1.0h / pow(max(distance(vp2.xyz, ray.vp0.xyz), 1.0h), 2)
        };

        atten.x *= smoothstep(-0.1h, 0.0h, dz.x - theta.x);
        atten.y *= smoothstep(-0.1h, 0.0h, dz.y - theta.y);

        gi += illum1.xyz * atten.x * ndotl.x;
        gi += illum2.xyz * atten.y * ndotl.y;

        theta = max(theta, dz);
        count += 1.0f;
    }

    return gi / max(count, 1.0f);
}

inline half4 PrePass(v2f_img IN) : SV_TARGET
{
    half3 ambient = SampleTexel(IN.uv);
    half3 direct = SampleGBuffer3(IN.uv);
    half depth = LinearEyeDepth(SampleZBuffer(IN.uv));
    return half4(ambient * _SSGIIntensity + direct, depth);
}

inline half4 IndirectDiffuse(v2f_img IN) : SV_TARGET
{
    // coordinate
    float4 vpos, wpos;
    half depth;

    SampleCoordinates(IN.uv, vpos, wpos, depth);

    // normal
    half3 wnrm = SampleGBuffer2(IN.uv);
    wnrm = normalize(mad(wnrm, 2.0f, -1.0f));
    half3 vnrm = mul(_WorldToViewMatrix, wnrm);

    // view direction
    half3 vdir = normalize(-vpos.xyz);
    half3 gi = 0.0h;

    if (depth < _SSGIFadeDepth)
    {
        float slice = FULL_PI / _SSGINumSample;

        ray ray;

        ray.uv0 = IN.uv;
        ray.vp0 = vpos;
        ray.nrm = vnrm;
        ray.len = _SSGIRayLength * mad(GradientNoise(IN.uv * 1.6f), 0.8f, 0.6f);

        float offset = GradientNoise(IN.uv * 2.1f);

        [unroll]
        for (float iter = 0.5f; iter < _SSGINumSample; iter += 1.0f)
        {
            float4 dir = 0.0h;
            sincos((iter - offset) * slice, dir.y, dir.x);
            dir.xyz = normalize(dir.xyz - vdir * dot(dir.xyz, vdir));

            ray.vp1 = mad( dir, ray.len, vpos);
            ray.vp2 = mad(-dir, ray.len, vpos);

            float4 sp1 = mul(unity_CameraProjection, ray.vp1);
            float4 sp2 = mul(unity_CameraProjection, ray.vp2);

            sp1.xy /= sp1.w;
            sp2.xy /= sp2.w;

            ray.uv1 = mad(sp1.xy, 0.5f, 0.5f);
            ray.uv2 = mad(sp2.xy, 0.5f, 0.5f);

            gi += HorizonTrace(ray);
        }
    }

    gi /= _SSGINumSample;
    gi = clamp(gi, 0.0h, 4.0h);

    return half4(gi, 1.0h);
}

inline half4 BilateralBlur(v2f_img IN) : SV_TARGET
{
    half3 sum = 0.0h;
    half norm = 0.0h;

    half zRef = LinearEyeDepth(SampleZBuffer(IN.uv));
    half3 nRef = mad(SampleGBuffer2(IN.uv), 2.0h, -1.0h);

    for(int x = -KERNEL_TAPS; x <= KERNEL_TAPS; x ++)
    {
        for(int y = -KERNEL_TAPS; y <+ KERNEL_TAPS; y ++)
        {
            float2 offset = _MainTex_TexelSize.xy * float2(x, y) * KERNEL_STEP;
            //int2 offset = int2(x, y) * KERNEL_STEP;

            half3 gi = SampleTexel(IN.uv + offset);//SampleTexel(IN.uv, offset);

            half zSample = LinearEyeDepth(SampleZBuffer(IN.uv + offset));
            half3 nSample = mad(SampleGBuffer2(IN.uv + offset), 2.0h, -1.0h);

            half correction = torusKernel[x + KERNEL_TAPS] * torusKernel[y + KERNEL_TAPS];
            correction = correction * exp(-abs(zSample - zRef) * 8.0h);
            correction = correction * pow(max(0, dot(nSample, nRef)), 128);
            
            sum += gi * correction;
            norm += correction;
        }
    }

    sum /= norm;
    sum = clamp(sum, 0.0h, 4.0h);

    return half4(sum, 1.0f);
}

inline half4 TemporalFilter(v2f_img IN) : SV_TARGET
{
    // coordinate
    float4 vpos, wpos;
    half depth;

    SampleCoordinates(IN.uv, vpos, wpos, depth);

    // ambient occlusion history
    float2 uvOld = GetAccumulationUv(wpos);
    float4 wpOld = GetAccumulationPos(uvOld);
    half3 giOld = SampleGI(uvOld);
    half3 gi = SampleTexel(IN.uv);

    gi *= SampleGBuffer0(IN.uv);
    //gi *= _SSGIIntensity;

    if (_SSGIMixFactor > 0.0h)
    {
        float factor = exp(-distance(wpOld, wpos) * 16.0h);
        factor = min(factor * _SSGIMixFactor, 0.96h);
        gi = lerp(gi, giOld, factor);
    }

    return half4(gi, 1.0h);
}

inline half4 CollectGI(v2f_img IN) : SV_TARGET
{
    half3 ambient = SampleTexel(IN.uv);
    half3 direct = SampleGBuffer3(IN.uv);
    return half4(ambient * _SSGIIntensity + direct, 1.0h);
}

#endif