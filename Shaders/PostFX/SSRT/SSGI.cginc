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
    #define _SSGINumSample 8
#endif

#ifndef _SSGINumStride
    #define _SSGINumStride 4
#endif

#define KERNEL_TAPS 8

#ifndef KERNEL_STEP
    #define KERNEL_STEP 1
#endif

#define beta 2.0f

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
    float2 uv;
    float3 pos;
    float3 nrm;
    float3 dir;
    float3 noise;
    float r;
    float t;
    // specular f0
    float3 f0;
    // beckmann roughness
    float a;
};

inline float GetMinimumStep(ray ray)
{
    float4 sp = mul(unity_CameraProjection, mad(ray.r, ray.dir, ray.pos));
    return length(ray.dir.xy * _HierachicalIrradianceBuffer0_TexelSize.xy) / length(sp.xy / sp.w * 0.5f + 0.5f - ray.uv);
}

inline float4 SampleIrradianceBufferMip(float2 uv, uint mip)
{
    if      (mip > 3)   return _HierachicalIrradianceBuffer4.Sample(sampler_HierachicalIrradianceBuffer4, uv);
    else if (mip > 2)   return _HierachicalIrradianceBuffer3.Sample(sampler_HierachicalIrradianceBuffer3, uv);
    else if (mip > 1)   return _HierachicalIrradianceBuffer2.Sample(sampler_HierachicalIrradianceBuffer2, uv);
    else if (mip > 0)   return _HierachicalIrradianceBuffer1.Sample(sampler_HierachicalIrradianceBuffer1, uv);
    else                return _HierachicalIrradianceBuffer0.Sample(sampler_HierachicalIrradianceBuffer0, uv);
}

inline float4 SampleIrradianceBufferMip(float2 uv, int2 offset, uint mip)
{
    if      (mip > 3)   return _HierachicalIrradianceBuffer4.Sample(sampler_HierachicalIrradianceBuffer4, uv, offset);
    else if (mip > 2)   return _HierachicalIrradianceBuffer3.Sample(sampler_HierachicalIrradianceBuffer3, uv, offset);
    else if (mip > 1)   return _HierachicalIrradianceBuffer2.Sample(sampler_HierachicalIrradianceBuffer2, uv, offset);
    else if (mip > 0)   return _HierachicalIrradianceBuffer1.Sample(sampler_HierachicalIrradianceBuffer1, uv, offset);
    else                return _HierachicalIrradianceBuffer0.Sample(sampler_HierachicalIrradianceBuffer0, uv, offset);
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

inline float4 SampleViewPosition(float2 uv)
{
    float4 depth = SampleIrradianceBufferMip(uv, 0).w;
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

void HorizonTrace(ray ray, float2 theta, inout uint mask, inout float3 diffuse, inout float3 specular)
{
    uint power = max(1, min(4, _SSGIStepPower));

    float str = 0.0f;
    float minStr = GetMinimumStep(ray) * (ray.noise.x + 1.0f);

    uint2 pHorizon = {0xFFFFFFFFu, 0xFFFFFFFFu};

    [unroll]
    for (uint iter = 0; iter < _SSGINumStride && str < 1.0f; iter ++)
    {
        uint mip = min(iter, 4);
        str = max(str + minStr * pow(2, mip), pow(((float)iter + ray.noise.x) / _SSGINumStride, power));

        //
        // horizon trace
        //

        // ray length
        float len = ray.r * str;

        // sampling position (view space)
        float2x4 vp = {
            float4(mad(ray.dir, len, ray.pos), 1.0f),
            float4(mad(ray.dir,-len, ray.pos), 1.0f),
        };

        // sampling position (screen space)
        float2x4 sp = {
            mul(unity_CameraProjection, vp[0]),
            mul(unity_CameraProjection, vp[1])
        };

        // sampling position (uv space)
        float2x2 uv = {
            sp[0].xy / sp[0].w * 0.5f + 0.5f,
            sp[1].xy / sp[1].w * 0.5f + 0.5f
        };

        // irradiance map
        float2x4 ir = {
            SampleIrradianceBufferMip(uv[0], mip),
            SampleIrradianceBufferMip(uv[1], mip)
        };

        // sampled depth
        float4 z = {
            ir[0].w, ir[1].w, 0.0f, 0.0f
        };

        z.zw = saturate(z.xy + ray.t);

        // front face position (view space)
        float2x4 facePos = {
            mul(_ClipToViewMatrix, float4(mad(uv[0], 2.0f, -1.0f), 1.0f, 1.0f)),
            mul(_ClipToViewMatrix, float4(mad(uv[1], 2.0f, -1.0f), 1.0f, 1.0f))
        };

        // back face position (view space)
        float2x4 backPos = facePos;

        facePos[0] = float4(facePos[0].xyz * z[0] / facePos[0].w, 1.0f);
        facePos[1] = float4(facePos[1].xyz * z[1] / facePos[1].w, 1.0f);
        backPos[0] = float4(backPos[0].xyz * z[2] / backPos[0].w, 1.0f);
        backPos[1] = float4(backPos[1].xyz * z[3] / backPos[1].w, 1.0f);

        // horizon angle
        float4 horizon = {
            dot(normalize(facePos[0].xyz - ray.pos), ray.dir),
            dot(normalize(facePos[1].xyz - ray.pos),-ray.dir),
            dot(normalize(backPos[0].xyz - ray.pos), ray.dir),
            dot(normalize(backPos[1].xyz - ray.pos),-ray.dir)
        };

        horizon = FastArcCos(horizon);

        horizon = horizon * sign(float4(
            facePos[0].z - vp[0].z, facePos[1].z - vp[1].z,
            backPos[0].z - vp[0].z, backPos[1].z - vp[1].z
        ));

        // hemisphere threshold
        /*
        float threshold = FastArcCos(str);
        horizon = min(horizon, threshold);
        */

        //
        // visibility bitmask
        //

        // clamp horizon angle
        horizon = clamp(horizon - theta.xyxy, 0.0f, UNITY_PI);

        // 32-bit length
        float segment = UNITY_PI / 32.0f;
        // horizon index
        uint4 index = (uint4)(horizon / segment.xxxx);
        uint4 visibility = 0xFFFFFFFFu << (index + 1);

        // backward direction
        // reverse bits: 000011 -> 110000
        visibility.yw = reversebits(visibility.yw);
        // backface visibility
        // flip bits: 000011 -> 111100
        visibility.zw = ~visibility.zw;

        //
        // lighting calculation
        //

        // light vector
        float2x3 ldir = {
            normalize(facePos[0].xyz - ray.pos),
            normalize(facePos[1].xyz - ray.pos)
        };

        // half vector
        float2x3 hdir = {
            normalize(ldir[0] + normalize(-ray.pos)),
            normalize(ldir[1] + normalize(-ray.pos))
        };

        float ndotv = saturate(dot(ray.nrm, normalize(-ray.pos)));

        float2 ndotl = {
            saturate(dot(ldir[0], ray.nrm)),
            saturate(dot(ldir[1], ray.nrm))
        };

        float2 ndoth = {
            saturate(dot(ray.nrm, hdir[0])),
            saturate(dot(ray.nrm, hdir[1]))
        };

        float2 ldoth = {
            saturate(dot(ldir[0], hdir[0])),
            saturate(dot(ldir[1], hdir[1]))
        };

        // screen bound
        float2 screenBound = 1.0f;

        screenBound.x = uv[0].x > 1.0f || uv[0].x < 0.0f || uv[0].y > 1.0f || uv[0].y < 0.0f ? 0.0f : 1.0f;
        screenBound.y = uv[1].x > 1.0f || uv[1].x < 0.0f || uv[1].y > 1.0f || uv[1].y < 0.0f ? 0.0f : 1.0f;

        // ndotl attenuation
        ir[0].xyz *= ndotl.x;
        ir[1].xyz *= ndotl.y;

        // shadow attenuation
        ir[0].xyz *= (float)countbits((~visibility.x) & mask) / 32.0f;
        ir[1].xyz *= (float)countbits((~visibility.y) & mask) / 32.0f;

        // brdf
        diffuse += ir[0].xyz * screenBound.x;
        diffuse += ir[1].xyz * screenBound.y;

        // specular
        /*
        specular += ir[0].xyz * ray.f0 * pow(ndoth.x, 1.0f / ray.a);
        specular += ir[1].xyz * ray.f0 * pow(ndoth.y, 1.0f / ray.a);
        */
        specular += ir[0].xyz * DGGX(ray.a, ndoth.x, 1.0f) * VSmith(ray.a, ndotv, ndotl.x, 1.0f) * FSchlick(ray.f0, ldoth.x);
        specular += ir[1].xyz * DGGX(ray.a, ndoth.y, 1.0f) * VSmith(ray.a, ndotv, ndotl.y, 1.0f) * FSchlick(ray.f0, ldoth.y);
        
        // update visibility mask
        visibility.xy = visibility.xy | visibility.zw;
        mask = mask & (visibility.x & visibility.y);
    }
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

void IndirectDiffuse(v2f_mrt IN, out half4 mrt0: SV_TARGET0, out half4 mrt1: SV_TARGET1)
{
    float4 vpos;
    float depth;

    float2 uv = IN.uv;

    // position
    depth = SampleIrradianceBufferMip(uv, 0).w;
    float4 spos = float4(mad(uv, 2.0f, -1.0f), 1.0f, 1.0f);
    vpos = mul(_ClipToViewMatrix, spos);
    vpos = float4(vpos.xyz * depth / vpos.w, 1.0f);

    // normal
    float3 wnrm = SampleGBuffer2(uv);
    wnrm = normalize(mad(wnrm, 2.0f, -1.0f));
    float3 vnrm = mul(_WorldToViewMatrix, wnrm);
    float3 vdir = normalize(-vpos.xyz);

    if (-vpos.z > _SSGIFadeDepth)
    {
        discard;
    }

    float3 noise = SampleNoise(uv);

    ray ray;
    ray.uv = uv;
    ray.pos = vpos;
    ray.nrm = vnrm;
    ray.noise = noise;

    ray.r = max(_SSGIRayLength, 0.001f);
    ray.t = max(_SSGIMeanDepth, 0.001f);

    // convert to linear 0-1 depth
    ray.t = saturate((ray.t - _ProjectionParams.y) / (_ProjectionParams.z - _ProjectionParams.y));

    float4 gbuffer1 = SampleGBuffer1(IN.uv);
    ray.f0 = gbuffer1.xyz;
    ray.a = lerp(1.0f, _SSGIRoughness, gbuffer1.w);
    ray.a = ray.a * ray.a;

    float slice = UNITY_PI / _SSGINumSample;
    
    float3 diffuse = 0.0f;
    float3 specular = 0.0f;

    //[unroll]
    for (uint iter = 0; iter < _SSGINumSample; iter ++)
    {
        // sampling direction
        ray.dir = 0.0f;
        sincos(slice * ((float)iter + 0.5f - noise.z), ray.dir.x, ray.dir.y);
        ray.dir = normalize(ray.dir - dot(ray.dir, vdir) * vdir);

        // normal projection plane
        // project to view direction-sample direction plane
        float3 proj = dot(vnrm, vdir) * vdir + dot(vnrm, ray.dir.xyz) * ray.dir.xyz;
        float gamma = clamp(FastArcCos(dot(normalize(proj), vdir)) * sign(dot(proj, ray.dir.xyz)), -HALF_PI, HALF_PI);

        float2 theta = { -gamma, gamma };
        uint mask = 0xFFFFFFFFu;

        HorizonTrace(ray, theta, mask, diffuse, specular);
    }

    diffuse  /= _SSGINumSample;
    specular /= _SSGINumSample;

    diffuse  /= _SSGINumStride;
    specular /= _SSGINumStride;

    mrt0 = half4(diffuse, GetLuminance(diffuse));
    mrt1 = half4(specular, GetLuminance(specular));

    mrt0.w *= mrt0.w;
    mrt1.w *= mrt1.w;
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

    float depth = LinearEyeDepth(SampleZBuffer(IN.uv));

    diffuse = depth > _SSGIFadeDepth ? 0.0h : diffuse;
    specular = depth > _SSGIFadeDepth ? 0.0h : specular;

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