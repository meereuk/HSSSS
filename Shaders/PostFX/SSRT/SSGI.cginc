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

uniform Texture2D _HierachicalIrradianceBuffer4;
uniform SamplerState sampler_HierachicalIrradianceBuffer4;
uniform float4 _HierachicalIrradianceBuffer4_TexelSize;

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

#define KERNEL_TAPS 8

#ifndef KERNEL_STEP
    #define KERNEL_STEP 1
#endif

static const int2 neighbors[KERNEL_TAPS] = 
{
    {  1,  0 }, {  1,  1 }, {  0,  1 }, { -1,  1 },
    { -1,  0 }, { -1, -1 }, {  0, -1 }, {  1, -1 },
};

static const half weights[KERNEL_TAPS] = 
{
    0.50h, 0.25h, 0.50h, 0.25h,
    0.50h, 0.25h, 0.50h, 0.25h
};

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
    // initial tangents
    float2 tan;
};

inline float4 SampleIrradianceBufferLOD(float2 uv, uint lod)
{
    if (lod == 4)
    {
        return _HierachicalIrradianceBuffer4.Sample(sampler_HierachicalIrradianceBuffer4, uv);
    }

    else if (lod == 3)
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

inline float4 SampleIrradianceBufferLOD(float2 uv, int2 offset, uint lod)
{
    if (lod == 4)
    {
        return _HierachicalIrradianceBuffer4.Sample(sampler_HierachicalIrradianceBuffer4, uv, offset);
    }

    else if (lod == 3)
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

inline void SampleFlipBuffer(float2 uv, out half4 diffuse, out half4 specular)
{
    diffuse = _SSGIFlipDiffuseBuffer.Sample(sampler_SSGIFlipDiffuseBuffer, uv);
    specular = _SSGIFlipSpecularBuffer.Sample(sampler_SSGIFlipSpecularBuffer, uv);
}

inline void SampleFlopBuffer(float2 uv, out half4 diffuse, out half4 specular)
{
    diffuse = _SSGIFlopDiffuseBuffer.Sample(sampler_SSGIFlopDiffuseBuffer, uv);
    specular = _SSGIFlopSpecularBuffer.Sample(sampler_SSGIFlopSpecularBuffer, uv);
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

    if (iter < 3)
    {
        lod = 0;
    }

    else if (iter < 5)
    {
        lod = 1;
    }

    else if (iter < 7)
    {
        lod = 2;
    }

    else if (iter < 9)
    {
        lod = 3;
    }

    else
    {
        lod = 4;
    }

    return lod;
}

inline half GetLuminance(half3 color)
{
    return dot(half3(0.299h, 0.587h, 0.114h), color);
}

// blinn-phong
inline half DBlinn(half a2, half NdotH)
{
    return clampInfinite(pow(NdotH, 2.0h / a2 - 2.0h) / a2);
}

inline float2 GetInitialTangent(float3 nrm, float3 dir)
{
    float3 vec = normalize(dir - nrm * dot(dir, nrm));
    float tangent = vec.z / length(vec.xy);
    return float2(tangent, -tangent) - 2.0h;
}

inline void HorizonTrace(ray ray, out half3 diffuse, out half3 specular)
{
    uint power = max(1, _SSGIStepPower);

    float2 duv = ray.uv[1] - ray.uv[0];
    float slope = duv.y / duv.x;

    float minStr[5] = {
        min(length(_HierachicalIrradianceBuffer0_TexelSize.xx * float2(1.0f, slope)), length(_HierachicalIrradianceBuffer0_TexelSize.yy * float2(1.0f / slope, 1.0f))) / length(duv),
        min(length(_HierachicalIrradianceBuffer1_TexelSize.xx * float2(1.0f, slope)), length(_HierachicalIrradianceBuffer1_TexelSize.yy * float2(1.0f / slope, 1.0f))) / length(duv),
        min(length(_HierachicalIrradianceBuffer2_TexelSize.xx * float2(1.0f, slope)), length(_HierachicalIrradianceBuffer2_TexelSize.yy * float2(1.0f / slope, 1.0f))) / length(duv),
        min(length(_HierachicalIrradianceBuffer3_TexelSize.xx * float2(1.0f, slope)), length(_HierachicalIrradianceBuffer3_TexelSize.yy * float2(1.0f / slope, 1.0f))) / length(duv),
        min(length(_HierachicalIrradianceBuffer4_TexelSize.xx * float2(1.0f, slope)), length(_HierachicalIrradianceBuffer4_TexelSize.yy * float2(1.0f / slope, 1.0f))) / length(duv)
    };

    diffuse = 0.0h;
    specular = 0.0h;

    float3 vdir = {0.0f, 0.0f, 1.0f};
    float2 theta = ray.tan;
    float str = 0.0f;
    float div = 0.0f;

    [unroll]
    for (float iter = 1.0f; iter <= _SSGINumStride && str <= 1.0f; iter += 1.0f)
    {
        uint lod = GetIrradianceLOD(iter);

        float ds = max(str + minStr[lod], pow(iter / _SSGINumStride, power)) - str;
        str = str + ds;

        for (int i = 0; i < 2; i ++)
        {
            float2 uv = lerp(ray.uv[0], ray.uv[i + 1], str);

            bool frustum = uv.x <= 1.0f;
            frustum = frustum && 0.0f <= uv.x;
            frustum = frustum && uv.y <= 1.0f;
            frustum = frustum && 0.0f <= uv.y;

            if (frustum)
            {
                float4 ir = SampleIrradianceBufferLOD(uv, lod);
                float4 sp = float4(mad(uv, 2.0f, -1.0f), 1.0f, 1.0f);
                float4 vp = mul(_ClipToViewMatrix, sp);
                vp = float4(vp.xyz * ir.w / vp.w, 1.0f);

                // sampling point normal (approx.)
                float3 vn = cross(ddy_fine(vp.xyz), ddx_fine(vp.xyz));
                vn = normalize(vn);

                half3 ldir = normalize(vp.xyz - ray.vp.xyz);
                half3 hdir = normalize(ldir + vdir);
                half ndotl = saturate(dot(ray.vn, ldir));
                half ndoth = saturate(dot(ray.vn, hdir));
                half ldoth = saturate(dot(ldir, hdir));

                // ambient light intensity
                ir.xyz = ir.xyz * ndotl * ds * ds;
                ir.xyz /= max(abs(vn.z), 0.1h);

                // shadow
                half dz = (vp.z - ray.vp.z - lerp(0.002h, 0.000h, str)) / distance(vp.xy, ray.vp.xy);
                ir.xyz = ir.xyz * smoothstep(-0.01h * str, 0.01h * str, dz - theta[i]);
                theta[i] = max(theta[i], dz);

                // lambertian diffuse 
                diffuse += ir.xyz;
                // blinn-phong specular
                specular += ir.xyz * FSchlick(ray.f0, ldoth) * DBlinn(ray.a, ndoth) * 0.25h;

                div += ds * ds;
            }
        }
    }

    diffuse /= div;
    specular /= div;
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
    half4 diffuse, specular;
    SampleGIHistory(IN.uv, diffuse, specular);
    half4 albedo = SampleGBuffer0(IN.uv);
    half4 direct = SampleGBuffer3(IN.uv);
    half3 ambient = mad(diffuse.xyz, albedo.xyz, specular.xyz);
    float depth = Linear01Depth(SampleZBuffer(IN.uv));
    return half4(mad(ambient, _SSGISecondary, direct.xyz), depth);
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
            float2x2 rotation = {
                { cos((iter - offset) * slice), -sin((iter - offset) * slice) },
                { sin((iter - offset) * slice),  cos((iter - offset) * slice) }
            };

            float4 dir = 0.0h;

            dir.xy = normalize(ray.vn.xy);
            dir.xy = mul(rotation, dir.xy);
            //sincos((iter - offset) * slice, dir.y, dir.x);

            ray.tan = GetInitialTangent(ray.vn, dir);

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

        diffuse = clamp(diffuse / _SSGINumSample, 0.0h, 8.0h);
        specular = clamp(specular / _SSGINumSample, 0.0h, 8.0h);

        mrt0 = half4(diffuse, GetLuminance(diffuse));
        mrt1 = half4(specular, GetLuminance(specular));

        mrt0.w *= mrt0.w;
        mrt1.w *= mrt1.w;
    }
}

void BilateralBlur(v2f_mrt IN, out half4 mrt0: SV_TARGET0, out half4 mrt1: SV_TARGET1)
{
    mrt0 = 0.0h;
    mrt1 = 0.0h;

    float4 vpos, wpos;
    float depth;

    SampleCoordinates(IN.uv, vpos, wpos, depth);

    if (depth > _SSGIFadeDepth)
    {
        return;
    }

    else
    {
        half4 wnrm = SampleGBuffer2(IN.uv);
        wnrm.xyz = normalize(mad(wnrm.xyz, 2.0h, -1.0h));
        half3 vnrm = mul(_WorldToViewMatrix, wnrm.xyz);

        #if defined(_SAMPLE_FLOP)
            SampleFlopBuffer(IN.uv, mrt0, mrt1);
        #else
            SampleFlipBuffer(IN.uv, mrt0, mrt1);
        #endif

        half2 illum = { GetLuminance(mrt0.xyz), GetLuminance(mrt1.xyz) };
        half2 var = { max(0.0h, mrt0.w - illum.x * illum.x), max(0.0h, mrt1.w - illum.y * illum.y) };

        half2 norm = 1.0h;

        half minvar = 1.0h - 0.999h * smoothstep(0.2h, 0.8h, _SSGIMixFactor);

        [unroll]
        for (int i = 0; i < KERNEL_TAPS; i ++)
        {
            int2 offset = KERNEL_STEP * neighbors[i];
            float2 uv = IN.uv + (_ScreenParams.zw - 1.0f) * offset;
            half2 corr = weights[i];

            half4 diffuse = 0.0h;
            half4 specular = 0.0h;

            #if defined(_SAMPLE_FLOP)
                SampleFlopBuffer(uv, diffuse, specular);
            #else
                SampleFlipBuffer(uv, diffuse, specular);
            #endif

            // geometry aware
            float z = LinearEyeDepth(SampleZBuffer(IN.uv, offset));
            float2 dz = { ddx_fine(z), ddy_fine(z) };
            corr *= exp(-abs(z - depth) / (abs(dot(dz, offset)) + 0.001h));
            // normal aware
            half4 n = SampleGBuffer2(IN.uv, offset);
            n.xyz = normalize(mad(n.xyz, 2.0h, -1.0h));
            corr *= pow(saturate(dot(n.xyz, wnrm.xyz)), 64);
            // mask aware
            corr *= wnrm.w == n.w ? 1.0h : 0.0h;
            // luminance aware
            half2 lum = { GetLuminance(diffuse.xyz), GetLuminance(specular.xyz) };
            corr *= exp(-abs(lum - illum) / mad(var, 4.0h, minvar));

            mrt0 += diffuse * corr.x;
            mrt1 += specular * corr.y;
            norm += corr;
        }

        mrt0 /= norm.x;
        mrt1 /= norm.y;
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

    SampleFlipBuffer(IN.uv, diffuseCurrent, specularCurrent);
    SampleGIHistory(uvHistory, diffuseHistory, specularHistory);

    half3 normalCurrent = _CameraGBufferTexture2.Sample(sampler_CameraGBufferTexture2, IN.uv);
    half3 normalHistory = _CameraNormalHistory.Sample(sampler_CameraNormalHistory, uvHistory);

    normalCurrent = normalize(mad(normalCurrent, 2.0h, -1.0h));
    normalHistory = normalize(mad(normalHistory, 2.0h, -1.0h));

    half weight = _SSGIMixFactor * smoothstep(0.96h, 1.00h, dot(normalCurrent, normalHistory));

    weight = clamp(weight, 0.0h, 0.99h);

    mrt0 = lerp(diffuseCurrent,  diffuseHistory,  weight);
    mrt1 = lerp(specularCurrent, specularHistory, weight);
}

inline half4 CollectGI(v2f_img IN) : SV_TARGET
{
    half4 diffuse, specular;
    SampleFlopBuffer(IN.uv, diffuse, specular);
    half4 albedo = SampleGBuffer0(IN.uv);
    half4 direct = SampleGBuffer3(IN.uv);

    half3 ambient = mad(diffuse.xyz, albedo.xyz, specular.xyz);
    return half4(mad(ambient, _SSGIIntensity, direct.xyz), direct.a);
}

inline void StoreHistory(v2f_mrt IN, out half4 mrt0: SV_TARGET0, out half4 mrt1: SV_TARGET1, out fixed4 mrt2: SV_TARGET2, out half mrt3: SV_TARGET3)
{
    SampleFlopBuffer(IN.uv, mrt0, mrt1);
    mrt2 = SampleGBuffer2(IN.uv);
    mrt3 = SampleZBuffer(IN.uv);
}

inline void BlitFlipToFlop(v2f_mrt IN, out half4 mrt0: SV_TARGET0, out half4 mrt1: SV_TARGET1)
{
    SampleFlipBuffer(IN.uv, mrt0, mrt1);
}

inline void BlitFlopToFlip(v2f_mrt IN, out half4 mrt0: SV_TARGET0, out half4 mrt1: SV_TARGET2)
{
    SampleFlopBuffer(IN.uv, mrt0, mrt1);
}

inline half4 DebugGI(v2f_img IN) : SV_TARGET
{
    half4 color = SampleTexel(IN.uv);
    half illum = GetLuminance(color.xyz);

    return color;//color.w - illum * illum;
}

#endif