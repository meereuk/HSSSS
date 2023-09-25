#ifndef HSSSS_SSGI_CGINC
// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
#pragma exclude_renderers gles
// Upgrade NOTE: excluded shader from DX11 and Xbox360 because it uses wrong array syntax (type[size] name)
#pragma exclude_renderers d3d11 xbox360
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
    #define _SSGINumSample 2
#endif

#ifndef _SSGINumStride
    #define _SSGINumStride 4
#endif

/*
static const int2 neighbors[9] = {
    {  0,  0 },
    {  1,  0 },
    {  0,  1 },
    { -1,  0 },
    {  0, -1 },
    {  1,  1 },
    { -1,  1 },
    { -1, -1 },
    {  1, -1 }
    };
*/

struct ray
{
    /*
    float2 uv0;
    float2 uv1;
    float2 uv2;

    float4 vp0[9];
    float4 vp1;
    float4 vp2;

    half3 vn0[9];
    */

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

/*
inline float4x2 SampleUv(float2 uv)
{
    float4x2 nuv;

    for (int i = 0; i < 4; i ++)
    {
        nuv[i] = uv + (_ScreenParams.zw - 1.0f) * neighbors[i];
    }

    return nuv;
}

inline void SamplePosition(float2 uv, out float4 vpos[9])
{
    for (int i = 0; i < 9; i ++)
    {
        float2 nuv = uv + (_ScreenParams.zw - 1.0f) * neighbors[i];
        float4 spos = float4(mad(nuv, 2.0f, -1.0f), 1.0f, 1.0f);
        float depth = Linear01Depth(SampleZBuffer(uv, neighbors[i]));
        vpos[i] = mul(_ClipToViewMatrix, spos);
        vpos[i] = float4(vpos[i].xyz * depth / vpos[i].w, 1.0f);
    }
}

inline void SampleNormal(float2 uv, out half3 vnrm[9])
{
    for (int i = 0; i < 9; i ++)
    {
        vnrm[i] = SampleGBuffer2(uv, neighbors[i]);
        vnrm[i] = normalize(mad(vnrm[i], 2.0f, -1.0f));
        vnrm[i] = mul(_WorldToViewMatrix, vnrm[i]);
    }
}

inline void HorizonTrace(ray ray, out half3 diffuse[9], out half3 specular[9])
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

    for (int i = 0; i < 9; i ++)
    {
        diffuse[i] = 0.0h;
        specular[i] = 0.0h;
    }

    float str = 0.0f;

    for (float iter = 1.0f; iter <= _SSGINumStride; iter += 1.0f)
    {
        uint lod = GetLOD(iter);

        float ds = max(str + minStr[lod], pow(iter / _SSGINumStride, power)) - str;
        str = str + ds;

        float2 uv1 = lerp(ray.uv0, ray.uv1, str);
        float2 uv2 = lerp(ray.uv0, ray.uv2, str);

        half4 irad1 = SampleIrradianceBufferLOD(uv1, lod);
        half4 irad2 = SampleIrradianceBufferLOD(uv2, lod);

        float4 sp1 = float4(mad(uv1, 2.0f, -1.0f), 1.0f, 1.0f);
        float4 sp2 = float4(mad(uv1, 2.0f, -1.0f), 1.0f, 1.0f);

        float4 vp1 = mul(_ClipToViewMatrix, sp1);
        float4 vp2 = mul(_ClipToViewMatrix, sp2);

        vp1 = float4(vp1.xyz * Linear01Depth(irad1.w) / vp1.w, 1.0f);
        vp2 = float4(vp2.xyz * Linear01Depth(irad2.w) / vp2.w, 1.0f);

        for (int i = 0; i < 9; i ++)
        {
            diffuse[i] += irad1.xyz * dot(ray.vn0[i], normalize(vp1.xyz - ray.vp0[i].xyz));
            diffuse[i] += irad2.xyz * dot(ray.vn0[i], normalize(vp2.xyz - ray.vp0[i].xyz));
        }
    }

    for (int i = 0; i < 9; i ++)
    {
        diffuse[i] /= _SSGINumStride;
        specular[i] /= _SSGINumStride;
    }
}
*/

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

    half3 vdir = half3(0.0h, 0.0h, 1.0h);

    for (float iter = 1.0f; iter <= _SSGINumStride && str <= 1.0f; iter += 1.0f)
    {
        uint lod = GetIrradianceLOD(iter);

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
            vp.z = -LinearEyeDepth(ir.w);
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
            vp.z = -LinearEyeDepth(ir.w);
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
    half4 diffuse, specular;
    SampleGIHistory(IN.uv, diffuse, specular);
    half4 albedo = SampleGBuffer0(IN.uv);
    half4 direct = SampleGBuffer3(IN.uv);
    half3 ambient = mad(diffuse.xyz, albedo.xyz, specular.xyz);
    half depth = SampleZBuffer(IN.uv);
    return half4(mad(ambient, _SSGISecondary, direct.xyz), depth);
}

half4 GBufferDownSample(v2f_img IN): SV_TARGET
{
    half4 gbuffer = {
        dot(_MainTex.GatherRed  (sampler_MainTex, IN.uv), 0.25h),
        dot(_MainTex.GatherGreen(sampler_MainTex, IN.uv), 0.25h),
        dot(_MainTex.GatherBlue (sampler_MainTex, IN.uv), 0.25h),
        dot(_MainTex.GatherAlpha(sampler_MainTex, IN.uv), 0.25h)
    };

    return gbuffer;
}

/*
void IndirectDiffuse(v2f_mrt IN, out half4 mrt0: SV_TARGET0, out half4 mrt1: SV_TARGET1)
{
    float depth = SampleZBuffer(IN.uv);
    float4 spos = float4(mad(IN.uv, 2.0f, -1.0f), 1.0f, 1.0f);
    float4 vpos = mul(_ClipToViewMatrix, spos);
    vpos = float4(vpos.xyz * Linear01Depth(depth) / vpos.w, 1.0f);
    depth = LinearEyeDepth(depth);

    float3 vdir = float3(0.0f, 0.0f, 1.0f);

    mrt0 = 0.0h;
    mrt1 = 0.0h;

    if (depth > _SSGIFadeDepth)
    {
        return;
    }

    else
    {
        float3 noise = SampleNoise(IN.uv);

        ray ray;

        ray.uv0 = IN.uv;
        SampleNormal(IN.uv, ray.vn0);
        SamplePosition(IN.uv, ray.vp0);

        float radius = _SSGIRayLength * (noise.x + 0.5f);
        float slice = FULL_PI / _SSGINumSample;
        float offset = noise.z;

        for (float iter = 0.5h; iter < _SSGINumSample; iter += 1.0f)
        {
            float4 dir = 0.0h;
            sincos((iter - offset) * slice, dir.y, dir.x);
            dir.xyz = normalize(dir.xyz - vdir * dot(dir.xyz, vdir));

            ray.vp1 = mad( dir, radius, vpos);
            ray.vp2 = mad(-dir, radius, vpos);

            float4 sp1 = mul(unity_CameraProjection, ray.vp1);
            float4 sp2 = mul(unity_CameraProjection, ray.vp2);

            ray.uv1 = sp1.xy / sp1.w * 0.5f + 0.5f;
            ray.uv2 = sp2.xy / sp2.w * 0.5f + 0.5f;

            half3 diffuse[9];
            half3 specular[9];

            HorizonTrace(ray, diffuse, specular);

            mrt0 += half4(diffuse[0], 0.0h) / _SSGINumSample;
            mrt1 += half4(diffuse[1].r, diffuse[2].r, diffuse[3].r, diffuse[4].r) / _SSGINumSample;
        }
    }
}
*/

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
        radius = lerp(0.001f, 0.40f, pow(1.0f - weight, 2));
    #else
        radius = lerp(0.001f, 0.40f, pow(1.0f - weight, 2));
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

            half acc = pow(saturate(dot(nm.xyz, wnrm.xyz)), 4);
            acc *= exp(-4.0h * disk.z * disk.z);
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