#ifndef HSSSS_SSGI_CGINC
#define HSSSS_SSGI_CGINC

#pragma exclude_renderers gles

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

// history buffer
uniform Texture2D _SSGITemporalDiffuseBuffer;
uniform SamplerState sampler_SSGITemporalDiffuseBuffer;

uniform Texture2D _SSGITemporalSpecularBuffer;
uniform SamplerState sampler_SSGITemporalSpecularBuffer;

uniform Texture2D _CameraDepthHistory;
uniform SamplerState sampler_CameraDepthHistory;

uniform Texture2D _CameraNormalHistory;
uniform SamplerState sampler_CameraNormalHistory;

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

struct ray
{
    // uv
    float3x2 uv;
    // view space position
    float4 vp;
    // view space normal
    half3 vn;
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

inline half4 SampleIrradianceBufferLOD(float2 uv, int2 offset, uint lod)
{
    if (lod == 3)
    {
        return _HierachicalIrradianceBuffer3.Sample(sampler_HierachicalIrradianceBuffer3, uv, offset);
    }

    else if (lod == 2)
    {
        return _HierachicalIrradianceBuffer2.Sample(sampler_HierachicalIrradianceBuffer2, uv, offset);
    }

    else if (lod == 1)
    {
        return _HierachicalIrradianceBuffer1.Sample(sampler_HierachicalIrradianceBuffer1, uv, offset);
    }

    else
    {
        return _HierachicalIrradianceBuffer0.Sample(sampler_HierachicalIrradianceBuffer0, uv, offset);
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

inline void SampleFlip(float2 uv, out half4 diffuse, out half4 specular)
{
    diffuse = SampleFlipDiffuse(uv);
    specular = SampleFlipSpecular(uv);
}

inline half4 SampleFlopDiffuse(float2 uv)
{
    return _SSGIFlopDiffuseBuffer.Sample(sampler_SSGIFlopDiffuseBuffer, uv);
}

inline half4 SampleFlopSpecular(float2 uv)
{
    return _SSGIFlopSpecularBuffer.Sample(sampler_SSGIFlopSpecularBuffer, uv);
}

inline void SampleFlop(float2 uv, out half4 diffuse, out half4 specular)
{
    diffuse = SampleFlopDiffuse(uv);
    specular = SampleFlopSpecular(uv);
}

inline float SampleZHistory(float2 uv)
{
    return _CameraDepthHistory.Sample(sampler_CameraDepthHistory, uv);
}

inline void SampleGIHistory(float2 uv, out half4 diffuse, out half4 specular)
{
    diffuse = _SSGITemporalDiffuseBuffer.Sample(sampler_SSGITemporalDiffuseBuffer, uv);
    specular = _SSGITemporalSpecularBuffer.Sample(sampler_SSGITemporalSpecularBuffer, uv);
}

inline float2 GetAccumulationUv(float4 wpos)
{
    float4 vpos = mul(_PrevWorldToViewMatrix, wpos);
    float4 spos = mul(_PrevViewToClipMatrix, vpos);
    return mad(spos.xy / spos.w, 0.5h, 0.5h);
}

inline float4 GetAccumulationPos(float2 uv)
{
    float vdepth = Linear01Depth(SampleZHistory(uv));
    // screen-space coordinate
    float4 spos = float4(mad(uv, 2.0f, -1.0f), 1.0f, 1.0h);
    // view-space coordinate
    float4 vpos = mul(_PrevClipToViewMatrix, spos);
    vpos = float4(vpos.xyz * vdepth / vpos.w, 1.0f);
    // world-space coordinate
    return mul(_PrevViewToWorldMatrix, vpos);
}

inline uint GetIrradianceLOD(float iter)
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

    return lod;
}

// blinn-phong
inline half DBlinn(half a2, half NdotH)
{
    return clampInfinite(pow(NdotH, 2.0h / a2 - 2.0h) / a2);
}

inline void HorizonTrace(ray ray, out half3 diffuse, out half3 specular)
{
    uint power = max(1, _SSGIStepPower);

    float2 duv = ray.uv[1] - ray.uv[0];
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

    float3 vdir = {0.0f, 0.0f, 1.0f};
    float2x2 theta = {{-10.0f, -10.0f}, {-10.0f, -10.0f}};
    float str = 0.0f;

    [unroll]
    for (float iter = 1.0f; iter <= _SSGINumStride && str <= 1.0f; iter += 1.0f)
    {
        uint lod = GetIrradianceLOD(iter);

        float ds = max(str + minStr[lod], pow(iter / _SSGINumStride, power)) - str;
        str = str + ds; 

        // uv
        float2x2 uv = {
            lerp(ray.uv[0], ray.uv[1], str),
            lerp(ray.uv[0], ray.uv[2], str)
        };

        float2x4 ir = {
            SampleIrradianceBufferLOD(uv[0], lod),
            SampleIrradianceBufferLOD(uv[1], lod)
        };

        float2x4 sp = {
            float4(mad(uv[0], 2.0f, -1.0f), 1.0f, 1.0f),
            float4(mad(uv[1], 2.0f, -1.0f), 1.0f, 1.0f)
        };

        float2x4 vp = {
            mul(_ClipToViewMatrix, sp[0]),
            mul(_ClipToViewMatrix, sp[1])
        };

        vp[0] = float4(vp[0].xyz * ir[0].w / vp[0].w, 1.0f);
        vp[1] = float4(vp[1].xyz * ir[1].w / vp[1].w, 1.0f);

        half2x3 ldir = {
            normalize(vp[0].xyz - ray.vp.xyz),
            normalize(vp[1].xyz - ray.vp.xyz)
        };

        half2x3 hdir = {
            normalize(ldir[0] + vdir),
            normalize(ldir[1] + vdir)
        };

        half2 ndotl = {
            saturate(dot(ray.vn, ldir[0])),
            saturate(dot(ray.vn, ldir[1]))
        };

        half2 ndoth = {
            saturate(dot(ray.vn, hdir[0])),
            saturate(dot(ray.vn, hdir[1]))
        };

        half2 ldoth = {
            saturate(dot(ldir[0], hdir[0])),
            saturate(dot(ldir[1], hdir[1]))
        };

        half2 dz = {
            (vp[0].z - ray.vp.z - 0.005f) / distance(vp[0].xy, ray.vp.xy),
            (vp[1].z - ray.vp.z - 0.005f) / distance(vp[1].xy, ray.vp.xy)
        };

        float2 threshold = {
            FastSqrt(max(0.0f, ray.len * ray.len - dot(vp[0].xy - ray.vp.xy, vp[0].xy - ray.vp.xy))),
            FastSqrt(max(0.0f, ray.len * ray.len - dot(vp[1].xy - ray.vp.xy, vp[1].xy - ray.vp.xy)))
        };

        ir[0].xyz = ir[0].xyz * ndotl[0] * step(theta[0].x, dz[0]) * ds;
        ir[1].xyz = ir[1].xyz * ndotl[1] * step(theta[1].x, dz[1]) * ds;

        ir[0].xyz = ir[0].xyz * step(abs(vp[0].z - ray.vp.z), threshold[0]);
        ir[1].xyz = ir[1].xyz * step(abs(vp[1].z - ray.vp.z), threshold[1]);

        diffuse += ir[0].xyz;
        diffuse += ir[1].xyz;

        specular += ir[0].xyz * FSchlick(ray.f0, ldoth[0]) * DBlinn(ray.a, ndoth[0]) * 0.25h;
        specular += ir[1].xyz * FSchlick(ray.f0, ldoth[1]) * DBlinn(ray.a, ndoth[1]) * 0.25h;

        theta[0].x = max(theta[0].x, dz[0]);
        theta[1].x = max(theta[1].x, dz[1]);
    }
}

inline float4 SampleViewPosition(float2 uv)
{
    float4 depth = SampleIrradianceBufferLOD(uv, 0).w;
    float4 spos = float4(mad(uv, 2.0f, -1.0f), 1.0f, 1.0f);
    float4 vpos = mul(_ClipToViewMatrix, spos);
    return float4(vpos.xyz * depth / vpos.w, 1.0f);
}

inline half3 SampleViewNormal(float2 uv)
{
    half3 vnrm = SampleGBuffer2(uv);
    vnrm = normalize(mad(vnrm, 2.0f, -1.0f));
    return mul(_WorldToViewMatrix, vnrm);
}

float4 GBufferPrePass(v2f_img IN): SV_TARGET
{
    float4 diffuse, specular;
    SampleGIHistory(IN.uv, diffuse, specular);
    half4 albedo = SampleGBuffer0(IN.uv);
    half4 direct = SampleGBuffer3(IN.uv);
    half3 ambient = mad(diffuse.xyz, albedo.xyz, specular.xyz);
    float depth = Linear01Depth(SampleZBuffer(IN.uv));
    return float4(mad(ambient, _SSGISecondary, direct.xyz), depth);
}

float4 GBufferDownSample(v2f_img IN): SV_TARGET
{
    float4 gbuffer = {
        dot(_MainTex.GatherRed  (sampler_MainTex, IN.uv), 0.25h),
        dot(_MainTex.GatherGreen(sampler_MainTex, IN.uv), 0.25h),
        dot(_MainTex.GatherBlue (sampler_MainTex, IN.uv), 0.25h),
        dot(_MainTex.GatherAlpha(sampler_MainTex, IN.uv), 0.25h)
    };

    return gbuffer;
}

void IndirectDiffuse(v2f_mrt IN, out half4 mrt0: SV_TARGET0, out half4 mrt1: SV_TARGET1)
{
    mrt0 = 0.0h;
    mrt1 = 0.0h;

    // temporal-aware blue noise
    float3 noise = SampleNoise(IN.uv);
    // view direction
    float3 vdir = float3(0.0h, 0.0h, 1.0h);
    // f0 and roughness
    half4 gbuffer1 = SampleGBuffer1(IN.uv);

    ray ray;

    ray.uv[0] = IN.uv;
    ray.vp = SampleViewPosition(IN.uv);
    ray.vn = SampleViewNormal(IN.uv);

    ray.len = _SSGIRayLength * (noise.x + 0.5f);
    ray.f0 = gbuffer1.xyz;

    // beckmann roughness to bllinn-phong exponent
    // http://simonstechblog.blogspot.com/2011/12/microfacet-brdf.html
    ray.a = lerp(0.99h, _SSGIRoughness, gbuffer1.w);
    ray.a = ray.a * ray.a;
    ray.a = ray.a * ray.a;

    ray.t = (noise.y + 0.5f) *_SSGIMeanDepth;

    if (-ray.vp.z > _SSGIFadeDepth)
    {
        return;
    }

    else
    {
        half3 diffuse = 0.0h;
        half3 specular = 0.0h;

        float slice = FULL_PI / _SSGINumSample;
        float offset = noise.z;

        for (float iter = 0.5h; iter < _SSGINumSample; iter += 1.0f)
        {
            float4 dir = 0.0h;
            sincos((iter - offset) * slice, dir.y, dir.x);

            float2x4 vp = {
                mad( dir, ray.len, ray.vp),
                mad(-dir, ray.len, ray.vp)
            };

            float2x4 sp = {
                mul(unity_CameraProjection, vp[0]),
                mul(unity_CameraProjection, vp[1])
            };

            ray.uv[1] = sp[0].xy / sp[0].w * 0.5f + 0.5f;
            ray.uv[2] = sp[1].xy / sp[1].w * 0.5f + 0.5f;

            half3 d;
            half3 s;

            HorizonTrace(ray, d, s);

            diffuse += d;
            specular += s;
        }

        diffuse = clamp(diffuse / _SSGINumSample, 0.0h, 4.0h);
        specular = clamp(specular / _SSGINumSample, 0.0h, 4.0h);

        mrt0 = half4(diffuse, 0.0h);
        mrt1 = half4(specular, 0.0h);
    }
}

void BilateralDiscBlur(v2f_mrt IN, out half4 mrt0: SV_TARGET0, out half4 mrt1: SV_TARGET1)
{
    mrt0 = 0.0h;
    mrt1 = 0.0h;

    float4 vpos, wpos;
    float depth;

    SampleCoordinates(IN.uv, vpos, wpos, depth);
    half4 wnrm = SampleGBuffer2(IN.uv);
    wnrm.xyz = normalize(mad(wnrm.xyz, 2.0h, -1.0h));
    half3 vnrm = mul(_WorldToViewMatrix, wnrm.xyz);

    float3x3 tbn;

    #if defined(_PREPASS_BLUR)
        tbn = GramSchmidtMatrix(IN.uv + 0.2f, vnrm);
    #elif defined(_POSTPASS_BLUR)
        tbn = GramSchmidtMatrix(IN.uv + 0.4f, vnrm);
    #else
        tbn = GramSchmidtMatrix(IN.uv + 0.6f, vnrm);
    #endif

    #if defined(_POSTPASS_BLUR)
        SampleFlop(IN.uv, mrt0, mrt1);
    #else
        SampleFlip(IN.uv, mrt0, mrt1);
    #endif
    
    half3 weight = mrt0.w;
    half sum = 1.0h;
    float radius;

    #if defined(_PREPASS_BLUR)
        radius = 0.01f;
    #elif defined(_POSTPASS_BLUR)
        radius = lerp(0.00f, 0.05f, pow(1.0f - weight, 2));
    #else
        radius = lerp(0.00f, 0.10f, pow(1.0f - weight, 2));
    #endif

    if (depth < _SSGIFadeDepth)
    {
        for (uint i = 0; i < 8; i ++)
        {
            float3 disk = PoissonDisk(i, 8);
            float3 dir = mul(float3(disk.xy, 0.0f), tbn);
            float4 vp = float4(mad(dir, radius, vpos.xyz), 1.0f);
            float4 sp = mul(unity_CameraProjection, vp);
            float2 uv = sp.xy / sp.w * 0.5f + 0.5f;

            half4 diffuse, specular;

            #if defined(_POSTPASS_BLUR)
                SampleFlop(uv, diffuse, specular);
            #else
                SampleFlip(uv, diffuse, specular);
            #endif

            half4 nm = SampleGBuffer2(uv);
            nm.xyz = normalize(mad(nm.xyz, 2.0h, -1.0h));

            float z = LinearEyeDepth(SampleZBuffer(uv));

            half acc = pow(saturate(dot(nm.xyz, wnrm.xyz)), 8);
            acc *= exp(-2.0h * disk.z * disk.z);
            acc *= exp(-64.0h * (z + vp.z) * (z + vp.z));
            acc *= wnrm.w == nm.w ? 1.0h : 0.0h;

            mrt0 += half4(diffuse.xyz, 0.0h) * acc;
            mrt1 += half4(specular.xyz, 0.0h) * acc;
            sum += acc;
        }

        mrt0.xyz /= sum;
        mrt1.xyz /= sum;

        mrt0.w = weight;
        mrt1.w = weight;
    }
}

void TemporalFilter(v2f_mrt IN, out half4 mrt0: SV_TARGET0, out half4 mrt1: SV_TARGET1)
{
    float4 vpCurrent, wpCurrent;
    float zCurrent;

    SampleCoordinates(IN.uv, vpCurrent, wpCurrent, zCurrent);

    float2 uvHistory = GetAccumulationUv(wpCurrent);
    float4 wpHistory = GetAccumulationPos(uvHistory);

    half4 diffuseCurrent, diffuseHistory;
    half4 specularCurrent, specularHistory;

    SampleFlop(IN.uv, diffuseCurrent, specularCurrent);
    SampleGIHistory(uvHistory, diffuseHistory, specularHistory);

    half3 normalCurrent = _CameraGBufferTexture2.Sample(sampler_CameraGBufferTexture2, IN.uv);
    half3 normalHistory = _CameraNormalHistory.Sample(sampler_CameraNormalHistory, uvHistory);

    normalCurrent = normalize(mad(normalCurrent, 2.0h, -1.0h));
    normalHistory = normalize(mad(normalHistory, 2.0h, -1.0h));

    half weight = saturate(_SSGIMixFactor * smoothstep(0.96h, 1.00h, dot(normalCurrent, normalHistory)));

    mrt0.xyz = lerp(diffuseCurrent.xyz, diffuseHistory.xyz, weight * 0.98h);
    mrt1.xyz = lerp(specularCurrent.xyz, specularHistory.xyz, weight * 0.98h);

    mrt0.w = weight;
    mrt1.w = weight;
}

inline half4 CollectGI(v2f_img IN) : SV_TARGET
{
    half4 diffuse, specular;
    SampleFlip(IN.uv, diffuse, specular);
    half4 albedo = SampleGBuffer0(IN.uv);
    half4 direct = SampleGBuffer3(IN.uv);

    half3 ambient = mad(diffuse.xyz, albedo.xyz, specular.xyz);
    return half4(mad(ambient, _SSGIIntensity, direct.xyz), direct.a);
}

inline void StoreHistory(v2f_mrt IN, out half4 mrt0: SV_TARGET0, out half4 mrt1: SV_TARGET1, out fixed4 mrt2: SV_TARGET2, out half mrt3: SV_TARGET3)
{
    SampleFlip(IN.uv, mrt0, mrt1);
    mrt2 = SampleGBuffer2(IN.uv);
    mrt3 = SampleZBuffer(IN.uv);
}

inline void BlitFlipToFlop(v2f_mrt IN, out half4 mrt0: SV_TARGET0, out half4 mrt1: SV_TARGET1)
{
    SampleFlip(IN.uv, mrt0, mrt1);
}

inline void BlitFlopToFlip(v2f_mrt IN, out half4 mrt0: SV_TARGET0, out half4 mrt1: SV_TARGET2)
{
    SampleFlop(IN.uv, mrt0, mrt1);
}

#endif