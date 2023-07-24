#ifndef HSSSS_SSGI_CGINC
#define HSSSS_SSGI_CGINC

#include "Common.cginc"

uniform half _SSGIIntensity;
uniform half _SSGISecondary;
uniform half _SSGIRayLength;
uniform half _SSGIMeanDepth;
uniform half _SSGIFadeDepth;
uniform half _SSGIMixFactor;
uniform uint _SSGIStepPower;
uniform uint _SSGIScreenDiv;

uniform Texture2D _SSGIIrradianceTexture;
uniform SamplerState sampler_SSGIIrradianceTexture;

#ifndef _SSGINumSample
    #define _SSGINumSample 2
#endif

#ifndef _SSGINumStride
    #define _SSGINumStride 4
#endif

#define KERNEL_TAPS 1

#ifndef KERNEL_STEP
    #define KERNEL_STEP 1
#endif

static const half torusKernel[3] =
{
    0.3h, 0.4h, 0.3h
};

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
    float minStr = length(_MainTex_TexelSize.xy) / length(ray.uv1 - ray.uv0);

    float2 theta = -1.0f;
    half3 gi = 0.0h;

    float sss = 0.0f;

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

        // sample irradiance
        half4 ir1 = SampleTexel(uv1);
        half4 ir2 = SampleTexel(uv2);

        vp1.z = -ir1.w;
        vp2.z = -ir2.w;

        // horizon calculation
        float2 threshold = ray.len * FastSqrt(1.0f - str * str);

        float2 dz = {
            vp1.z - ray.vp0.z,
            vp2.z - ray.vp0.z
        };

        // n dot l
        half2 ndotl = {
            saturate(dot(normalize(vp1.xyz - ray.vp0.xyz), ray.nrm)),
            saturate(dot(normalize(vp2.xyz - ray.vp0.xyz), ray.nrm))
        };

        dz /= abs(str * ray.len);

        gi += ir1.xyz * ndotl.x * step(theta.x, dz.x) * (str - sss);
        gi += ir2.xyz * ndotl.y * step(theta.y, dz.y) * (str - sss);

        theta = max(theta, dz);
        sss = str;
    }

    return gi;
}

inline half4 GBufferPrePass(v2f_img IN) : SV_TARGET
{
    // irradiance buffer
    half4 ambient = SampleTexel(IN.uv) * SampleGBuffer0(IN.uv);
    half3 direct = SampleGBuffer3(IN.uv);
    half depth = LinearEyeDepth(SampleZBuffer(IN.uv));
    return half4(mad(ambient, _SSGISecondary, direct), depth);
}

inline half4 IndirectDiffuse(v2f_img IN) : SV_TARGET
{
    // coordinate
    float4 vpos;
    float4 wpos;
    half depth;
    
    // interleaved uv
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
        //float2 uv = IN.uv + GradientNoise(frac((float) _FrameCount / 1024.5));
        float2 uv = IN.uv + 0.5f * Hash(Hash(_Time.y));

        ray ray;

        ray.uv0 = IN.uv;
        ray.vp0 = vpos;
        ray.nrm = vnrm;
        ray.len = _SSGIRayLength;
        ray.len *= SampleNoise(uv + 0.1f) + 0.5f;

        float slice = FULL_PI / _SSGINumSample;
        float offset = SampleNoise(uv + 0.3f);

        [unroll]
        for (float iter = 0.5h; iter < _SSGINumSample; iter += 1.0f)
        {
            float4 dir = 0.0h;
            sincos((iter - offset) * slice, dir.y, dir.x);
            dir.xyz = normalize(dir.xyz - vdir * dot(dir.xyz, vdir));

            ray.vp1 = mad( dir, ray.len, vpos);
            ray.vp2 = mad(-dir, ray.len, vpos);

            float4 sp1 = mul(unity_CameraProjection, ray.vp1);
            float4 sp2 = mul(unity_CameraProjection, ray.vp2);

            ray.uv1 = sp1.xy / sp1.w * 0.5f + 0.5f;
            ray.uv2 = sp2.xy / sp2.w * 0.5f + 0.5f;

            gi += HorizonTrace(ray);
        }
    }

    gi /= _SSGINumSample;
    gi = clamp(gi, 0.0h, 4.0h);

    return half4(gi, 1.0h);
}

inline half4 DeinterleaveGI(v2f_img IN) : SV_TARGET
{
    uint split = max(min(exp2(_SSGIScreenDiv), 8), 1);
    float2 uv = DecodeInterleavedUV(IN.uv, _MainTex_TexelSize, split);
    return SampleTexel(uv);
}

inline half4 BilateralBlur(v2f_img IN) : SV_TARGET
{
    half3 sum = 0.0h;
    half norm = 0.0h;

    half zRef = LinearEyeDepth(SampleZBuffer(IN.uv));
    half3 nRef = mad(SampleGBuffer2(IN.uv), 2.0h, -1.0h);

    for(int x = -KERNEL_TAPS; x <= KERNEL_TAPS; x ++)
    {
        for(int y = -KERNEL_TAPS; y <= KERNEL_TAPS; y ++)
        {
            float2 offset = _MainTex_TexelSize.xy * float2(x, y) * KERNEL_STEP;
            //int2 offset = int2(x, y) * KERNEL_STEP;

            half3 gi = SampleTexel(IN.uv + offset);

            half zSample = LinearEyeDepth(SampleZBuffer(IN.uv + offset));
            half3 nSample = mad(SampleGBuffer2(IN.uv + offset), 2.0h, -1.0h);

            half correction = torusKernel[x + KERNEL_TAPS] * torusKernel[y + KERNEL_TAPS];
            correction = correction * exp(-abs(zSample - zRef) * 2.0h);
            correction = correction * pow(max(0, dot(nSample, nRef)), 32);
            
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
    float depth;

    SampleCoordinates(IN.uv, vpos, wpos, depth);

    // ambient occlusion history
    float2 uvOld = GetAccumulationUv(wpos);
    float depthOld = LinearEyeDepth(SampleZHistory(uvOld));

    half3 giOld = SampleGI(uvOld);
    half3 gi = SampleTexel(IN.uv);

    if (_SSGIMixFactor > 0.0h)
    {
        half f = abs((depth - depthOld) / depth);
        half weight = 1.0h - smoothstep(0.0h, 0.01h, f);
        weight = saturate(min(weight * _SSGIMixFactor, 0.98h));
        gi = lerp(gi,  giOld, weight);
    }

    return half4(gi, 1.0h);
}

inline half4 CollectGI(v2f_img IN) : SV_TARGET
{
    half3 ambient = SampleTexel(IN.uv) * SampleGBuffer0(IN.uv);
    half3 direct = SampleGBuffer3(IN.uv);
    return half4(mad(ambient, _SSGIIntensity, direct), 1.0h);
}

#endif