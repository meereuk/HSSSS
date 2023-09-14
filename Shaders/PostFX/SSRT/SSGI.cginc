#ifndef HSSSS_SSGI_CGINC
#define HSSSS_SSGI_CGINC

#include "Common.cginc"
#include "MRT.cginc"
#include "Assets/HSSSS/Framework/Brdf.cginc"

uniform half _SSGIIntensity;
uniform half _SSGISecondary;
uniform half _SSGIRayLength;
uniform half _SSGIMeanDepth;
uniform half _SSGIRoughness;
uniform half _SSGIFadeDepth;
uniform half _SSGIMixFactor;
uniform uint _SSGIStepPower;

// hierachical irradiance buffers
uniform Texture2D _HierachicalIrradianceBuffer0;
uniform SamplerState sampler_HierachicalIrradianceBuffer0;
uniform float4 _HierachicalIrradianceBuffer0_TexelSize;

uniform Texture2D _HierachicalIrradianceBuffer1;
uniform SamplerState sampler_HierachicalIrradianceBuffer1;
uniform float4 _HierachicalIrradianceBuffer1_TexelSize;

uniform Texture2D _HierachicalIrradianceBuffer2;
uniform SamplerState sampler_HierachicalIrradianceBuffer2;
uniform float4 _HierachicalIrradianceBuffer2_TexelSize;

uniform Texture2D _HierachicalIrradianceBuffer3;
uniform SamplerState sampler_HierachicalIrradianceBuffer3;
uniform float4 _HierachicalIrradianceBuffer3_TexelSize;

// temporal flip-flop buffers
// diffuse
uniform Texture2D _SSGIFlipDiffuseBuffer;
uniform SamplerState sampler_SSGIFlipDiffuseBuffer;
uniform float4 _SSGIFlipDiffuseBuffer_TexelSize;

uniform Texture2D _SSGIFlopDiffuseBuffer;
uniform SamplerState sampler_SSGIFlopDiffuseBuffer;
uniform float4 _SSGIFlopDiffuseBuffer_TexelSize;

// specular
uniform Texture2D _SSGIFlipSpecularBuffer;
uniform SamplerState sampler_SSGIFlipSpecularBuffer;
uniform float4 _SSGIFlipSpecularBuffer_TexelSize;

uniform Texture2D _SSGIFlopSpecularBuffer;
uniform SamplerState sampler_SSGIFlopSpecularBuffer;
uniform float4 _SSGIFlopSpecularBuffer_TexelSize;

#ifndef _SSGINumSample
    #define _SSGINumSample 4
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

    // random thickness
    float t;
    
    // specular properties
    half3 f0;
    half3 a;
};

inline half4 SampleIrradianceBufferLOD(float2 uv, uint lod)
{
    if (lod == 3)
    {
        return _HierachicalIrradianceBuffer3.Sample(sampler_HierachicalIrradianceBuffer3, uv);
    }

    else if (lod == 2)
    {
        return _HierachicalIrradianceBuffer2.Sample(sampler_HierachicalIrradianceBuffer2, uv);
    }

    else if (lod == 1)
    {
        return _HierachicalIrradianceBuffer1.Sample(sampler_HierachicalIrradianceBuffer1, uv);
    }

    else
    {
        return _HierachicalIrradianceBuffer0.Sample(sampler_HierachicalIrradianceBuffer0, uv);
    }
}

inline half4 SampleFlipDiffuse(float2 uv)
{
    return _SSGIFlipDiffuseBuffer.Sample(sampler_SSGIFlipDiffuseBuffer, uv);
}

inline half4 SampleFlipSpecular(float2 uv)
{
    return _SSGIFlipSpecularBuffer.Sample(sampler_SSGIFlipSpecularBuffer, uv);
}

inline half4 SampleFlopDiffuse(float2 uv)
{
    return _SSGIFlopDiffuseBuffer.Sample(sampler_SSGIFlopDiffuseBuffer, uv);
}

inline half4 SampleFlopSpecular(float2 uv)
{
    return _SSGIFlopSpecularBuffer.Sample(sampler_SSGIFlopSpecularBuffer, uv);
}

// blinn-phong
inline half DBlinn(half a2, half NdotH)
{
    return clampInfinite(pow(NdotH, 2.0h / a2 - 2.0h) / a2);
}


inline void HorizonTrace(ray ray, out half3 diffuse, out half3 specular)
{
    uint power = max(1, _SSGIStepPower);

    float2 duv = ray.uv1 - ray.uv0;
    float slope = duv.y / duv.x;

    float4 minStr = {
        min(length(_HierachicalIrradianceBuffer0_TexelSize.xx * float2(1.0f, slope)), length(_HierachicalIrradianceBuffer0_TexelSize.yy * float2(1.0f / slope, 1.0f))),
        min(length(_HierachicalIrradianceBuffer1_TexelSize.xx * float2(1.0f, slope)), length(_HierachicalIrradianceBuffer1_TexelSize.yy * float2(1.0f / slope, 1.0f))),
        min(length(_HierachicalIrradianceBuffer2_TexelSize.xx * float2(1.0f, slope)), length(_HierachicalIrradianceBuffer2_TexelSize.yy * float2(1.0f / slope, 1.0f))),
        min(length(_HierachicalIrradianceBuffer3_TexelSize.xx * float2(1.0f, slope)), length(_HierachicalIrradianceBuffer3_TexelSize.yy * float2(1.0f / slope, 1.0f)))
    };

    minStr /= length(duv);

    diffuse = 0.0h;
    specular = 0.0h;

    float2 theta = -10.0f;

    float str = 0.0f;
    float sss = 0.0f;

    //half3 vdir = normalize(-ray.vp0.xyz);
    half3 vdir = half3(0.0h, 0.0h, 1.0h);

    [unroll]
    for (float iter = 1.0f; iter <= _SSGINumStride && str <= 1.0f; iter += 1.0f)
    {
        uint lod = 0;

        if (iter <= (_SSGINumStride / 4))
        {
            lod = 0;
        }

        else if (iter <= (_SSGINumStride / 2))
        {
            lod = 1;
        }

        else if (iter <= (_SSGINumStride * 3 / 4))
        {
            lod = 2;
        }

        else
        {
            lod = 3;
        }

        float ds = max(str + minStr[lod], pow(iter / _SSGINumStride, power)) - str;
        str = str + ds;

        // uv
        float2 uv1 = lerp(ray.uv0, ray.uv1, str);
        float2 uv2 = lerp(ray.uv0, ray.uv2, str);
        float threshold = ray.len * FastSqrt(1.0f - str * str);

        if (0.0f <= uv1.x && uv1.x <= 1.0f && 0.0f <= uv1.y && uv1.y <= 1.0f)
        {
            float4 vp = lerp(ray.vp0, ray.vp1, str);
            half4 ir = SampleIrradianceBufferLOD(uv1, lod);
            vp.z = -ir.w;
            float dz = vp.z - ray.vp0.z;

            if (dz - ray.t < threshold)
            {
            dz = min(threshold, dz);
            dz = dz / abs(str * ray.len);

            half3 ldir = normalize(vp.xyz - ray.vp0.xyz);
            half3 hdir = normalize(ldir + vdir);

            half ndotl = saturate(dot(ray.nrm, ldir));
            half ndoth = saturate(dot(ray.nrm, hdir));
            half ldoth = saturate(dot(ldir, hdir));

            ir.xyz *= ndotl;
            ir.xyz *= step(theta.x, dz);
            ir.xyz *= abs(ds);

            diffuse += ir.xyz;
            specular += ir.xyz * FSchlick(ray.f0, ldoth) * DBlinn(ray.a, ndoth) * 0.25h;

            theta.x = max(theta.x, dz);
            }
        }

        if (0.0f <= uv2.x && uv2.x <= 1.0f && 0.0f <= uv2.y && uv2.y <= 1.0f)
        {
            float4 vp = lerp(ray.vp0, ray.vp2, str);
            half4 ir = SampleIrradianceBufferLOD(uv2, lod);
            vp.z = -ir.w;
            float dz = vp.z - ray.vp1.z;

            if (dz - ray.t < threshold)
            {
            dz = min(threshold, dz);
            dz = dz / abs(str * ray.len);

            half3 ldir = normalize(vp.xyz - ray.vp0.xyz);
            half3 hdir = normalize(ldir + vdir);

            half ndotl = saturate(dot(ray.nrm, ldir));
            half ndoth = saturate(dot(ray.nrm, hdir));
            half ldoth = saturate(dot(ldir, hdir));

            ir.xyz *= ndotl;
            ir.xyz *= step(theta.y, dz);
            ir.xyz *= abs(ds);

            diffuse += ir.xyz;
            specular += ir.xyz * FSchlick(ray.f0, ldoth) * DBlinn(ray.a, ndoth) * 0.25h;

            theta.y = max(theta.y, dz);
            }
        }
    }
}

half4 GBufferPrePass(v2f_img IN): SV_TARGET
{
    // irradiance buffer
    half3 ambient = SampleTexel(IN.uv);
    half3 direct = SampleGBuffer3(IN.uv);
    half depth = LinearEyeDepth(SampleZBuffer(IN.uv));

    return half4(mad(ambient, _SSGISecondary, direct), depth);
}

void IndirectDiffuse(v2f_mrt IN, out half4 mrt0: SV_TARGET0, out half4 mrt1: SV_TARGET1)
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
    //half3 vdir = normalize(-vpos.xyz);
    half3 vdir = half3(0.0h, 0.0h, 1.0h);

    // f0 and roughness
    half4 gbuffer1 = SampleGBuffer1(IN.uv);

    half3 diffuse = 0.0h;
    half3 specular = 0.0h;

    if (depth < _SSGIFadeDepth)
    {
        float3 noise = SampleNoise(IN.uv);

        ray ray;

        ray.uv0 = IN.uv;
        ray.vp0 = vpos;
        ray.nrm = vnrm;
        ray.len = _SSGIRayLength;
        ray.len *= noise.x + 0.5f;

        ray.f0 = gbuffer1.xyz;

        // beckmann roughness to bllinn-phong exponent
        // http://simonstechblog.blogspot.com/2011/12/microfacet-brdf.html
        ray.a = lerp(0.99h, _SSGIRoughness, gbuffer1.w);
        ray.a = ray.a * ray.a;
        ray.a = ray.a * ray.a;

        ray.t = (noise.y + 0.5f) *_SSGIMeanDepth;

        float slice = FULL_PI / _SSGINumSample;
        float offset = noise.z;

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

            half3 d = 0.0h;
            half3 s = 0.0h;

            HorizonTrace(ray, d, s);

            diffuse += d;
            specular += s;
        }
    }

    diffuse = clamp(diffuse / _SSGINumSample, 0.0h, 4.0h);
    specular = clamp(specular / _SSGINumSample, 0.0h, 4.0h);

    mrt0 = half4(diffuse, 0.0h);
    mrt1 = half4(specular, 0.0h);
}

void BilateralBlur(v2f_mrt IN, out half4 mrt0: SV_TARGET0, out half4 mrt1: SV_TARGET1)
{
    mrt0 = 0.0h;
    mrt1 = 0.0h;

    half norm = 0.0h;

    half zRef = LinearEyeDepth(SampleZBuffer(IN.uv));
    half4 gRef = SampleGBuffer2(IN.uv);
    half3 nRef = mad(gRef.xyz, 2.0h, -1.0h);
    half mRef = saturate(1.0h - gRef.w);
    //half3 nRef = mad(SampleGBuffer2(IN.uv), 2.0h, -1.0h);

    if (zRef < _SSGIFadeDepth)
    {
        for(int x = -KERNEL_TAPS; x <= KERNEL_TAPS; x ++)
        {
            for(int y = -KERNEL_TAPS; y <= KERNEL_TAPS; y ++)
            {
                float2 offset = float2(x, y) * KERNEL_STEP;

                #ifdef _SAMPLE_FLOP
                    offset *= _SSGIFlopDiffuseBuffer_TexelSize.xy;
                    half3 diffuse = SampleFlopDiffuse(IN.uv + offset);
                    half3 specular = SampleFlopSpecular(IN.uv + offset);
                #else
                    offset *= _SSGIFlipDiffuseBuffer_TexelSize.xy;
                    half3 diffuse = SampleFlipDiffuse(IN.uv + offset);
                    half3 specular = SampleFlipSpecular(IN.uv + offset);
                #endif

                half3 gi = SampleTexel(IN.uv + offset);

                half zSample = LinearEyeDepth(SampleZBuffer(IN.uv + offset));
                half4 gSample = SampleGBuffer2(IN.uv + offset);
                half3 nSample = mad(gSample.xyz, 2.0h, -1.0h);
                half mSample = saturate(1.0h - gSample.w);

                half correction = torusKernel[x + KERNEL_TAPS] * torusKernel[y + KERNEL_TAPS];
                correction *= exp(-abs(zSample - zRef) * 4.0h);
                correction *= correction * pow(max(0, dot(nSample, nRef)), 16);
                correction *= mSample == mRef ? 1.0h : 0.0h;
            
                mrt0.xyz += diffuse * correction;
                mrt1.xyz += specular * correction;
                norm += correction;
            }
        }

        mrt0.xyz = clamp(mrt0.xyz / norm, 0.0h, 8.0h);
        mrt1.xyz = clamp(mrt1.xyz / norm, 0.0h, 8.0h);
    }
}

inline half4 TemporalFilter(v2f_img IN) : SV_TARGET
{
    half3 diffuse = _SSGIFlipDiffuseBuffer.Sample(sampler_SSGIFlipDiffuseBuffer, IN.uv);
    half3 specular = _SSGIFlipSpecularBuffer.Sample(sampler_SSGIFlipSpecularBuffer, IN.uv);
    half3 albedo = SampleGBuffer0(IN.uv);

    //return half4(mad(albedo, diffuse, specular), 0.0h);

    // coordinate
    float4 vpos, wpos;
    float depth;

    SampleCoordinates(IN.uv, vpos, wpos, depth);

    // ambient occlusion history
    float2 uvOld = GetAccumulationUv(wpos);
    float depthOld = LinearEyeDepth(SampleZHistory(uvOld));

    half3 giOld = SampleGI(uvOld);
    half3 gi = mad(albedo, diffuse, specular);

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
    half3 ambient = SampleTexel(IN.uv);
    half4 direct = SampleGBuffer3(IN.uv);
    return half4(mad(ambient, _SSGIIntensity, direct.rgb), direct.a);
}

#endif