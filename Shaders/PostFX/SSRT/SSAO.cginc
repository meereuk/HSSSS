#ifndef HSSSS_SSAO_CGINC
#define HSSSS_SSAO_CGINC

#pragma exclude_renderers gles

#include "Common.cginc"
#include "MRT.cginc"

uniform half _SSAOIntensity;
uniform half _SSAOLightBias;
uniform half _SSAORayLength;
uniform half _SSAOMeanDepth;
uniform half _SSAOFadeDepth;
uniform uint _SSAORayStride;
uniform uint _SSAOSubSample;

uniform Texture2D<float> _HierarchicalZBuffer0;
uniform Texture2D<float> _HierarchicalZBuffer1;
uniform Texture2D<float> _HierarchicalZBuffer2;
uniform Texture2D<float> _HierarchicalZBuffer3;
uniform Texture2D<float> _HierarchicalZBuffer4;

uniform SamplerState sampler_HierarchicalZBuffer0;
uniform SamplerState sampler_HierarchicalZBuffer1;
uniform SamplerState sampler_HierarchicalZBuffer2;
uniform SamplerState sampler_HierarchicalZBuffer3;
uniform SamplerState sampler_HierarchicalZBuffer4;

uniform Texture2D _SSAOMaskRenderTexture;
uniform SamplerState sampler_SSAOMaskRenderTexture;

uniform float4 _HierarchicalZBuffer0_TexelSize;
uniform float4 _HierarchicalZBuffer1_TexelSize;
uniform float4 _HierarchicalZBuffer2_TexelSize;
uniform float4 _HierarchicalZBuffer3_TexelSize;
uniform float4 _HierarchicalZBuffer4_TexelSize;

#ifndef _SSAONumSample
    #define _SSAONumSample 4
#endif

#ifndef _SSAONumStride
    #define _SSAONumStride 4
#endif

struct ray
{
    float2 uv;
    float3 pos;
    float3 dir;
    float3 noise;
    float r;
    float t;
};

inline float4 SampleMask(float2 uv)
{
    float4 mask = _SSAOMaskRenderTexture.Sample(sampler_SSAOMaskRenderTexture, uv);
    mask.xyz = normalize(mad(mask.xyz, 2.0f, -1.0f));
    return mask;
}

inline float SampleZBufferMip(float2 uv, uint mip)
{
    if      (mip > 3)   return _HierarchicalZBuffer4.Sample(sampler_HierarchicalZBuffer4, uv).x;
    else if (mip > 2)   return _HierarchicalZBuffer3.Sample(sampler_HierarchicalZBuffer3, uv).x;
    else if (mip > 1)   return _HierarchicalZBuffer2.Sample(sampler_HierarchicalZBuffer2, uv).x;
    else if (mip > 0)   return _HierarchicalZBuffer1.Sample(sampler_HierarchicalZBuffer1, uv).x;
    else                return _HierarchicalZBuffer0.Sample(sampler_HierarchicalZBuffer0, uv).x;
}

inline float GetMinimumStep(ray ray)
{
    float4 sp = mul(unity_CameraProjection, mad(ray.r, ray.dir, ray.pos));
    return length(ray.dir.xy * _HierarchicalZBuffer0_TexelSize.xy) / length(sp.xy / sp.w * 0.5f + 0.5f - ray.uv);
}

inline float DecodeVisibility(uint mask)
{
    float sum = 0.0f;
    float div = 0.0f;

    [unroll]
    for (uint index = 0; index < 32; index ++)
    {
        float2 angle = { (float)index, (float)index + 1.0f };
        angle = angle * UNITY_PI / 32.0f;

        float light = cos(angle.x) - cos(angle.y);
        uint visible = (mask >> index) & 1u;
        sum += light * (float)visible;
        div += light;
    }

    return sum / div;
}

inline float4 DecodeVisibility(float3 vdir, float3 pdir, float theta, uint mask)
{
    float4 vec = 0.0f;
    float  div = 0.0f;

    [unroll]
    for (uint index = 0; index < 32; index ++)
    {
        float2 angle = { (float)index, (float)index + 1.0f };
        angle = angle * UNITY_PI / 32.0f;

        float light = cos(angle.x) - cos(angle.y);
        uint visible = (mask >> index) & 1u;
        vec.w += light * (float)visible;
        div += light;

        float phi = 0.5f * (angle.x + angle.y) + theta;

        vec.xyz += normalize(cos(phi) * pdir + sin(phi) * vdir) * (float)visible;
    }

    vec.w /= div;
    return vec;
}

void HorizonTrace(ray ray, float2 theta, inout uint mask)
{
    uint power = max(1, min(4, _SSAORayStride));

    float str = 0.0f;
    float minStr = GetMinimumStep(ray) * (ray.noise.x + 1.0f);

    [unroll]
    for (uint iter = 0; iter < _SSAONumStride && str < 1.0f; iter ++)
    {
        uint mip = min(iter, 4);
        str = max(str + minStr * pow(2, mip), pow(((float)iter + ray.noise.x) / _SSAONumStride, power));

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

        // sampled depth
        float4 z = {
            SampleZBufferMip(uv[0], mip),
            SampleZBufferMip(uv[1], mip),
            0.0f, 0.0f
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
        float threshold = FastArcCos(str);
        horizon = min(horizon, threshold);

        //
        // visibility bitmask
        //

        // clamp horizon angle
        horizon = clamp(horizon - theta.xyxy, 0.0f, UNITY_PI);

        // 32-bit length
        float segment = UNITY_PI / 32.0f;
        uint4 index = (uint4)(horizon / segment.xxxx);
        uint4 visibility = 0xFFFFFFFFu << (index + 1);

        // backward direction
        visibility.yw = reversebits(visibility.yw);
        // backface visibility
        visibility.zw = ~visibility.zw;

        // update visibility mask
        visibility.xy = visibility.xy | visibility.zw;
        mask = mask & (visibility.x & visibility.y);
    }
}

inline float ZBufferPrePass(v2f_img IN) : SV_TARGET
{
    return Linear01Depth(SampleZBuffer(IN.uv));
}

float4 IndirectOcclusion(v2f_img IN) : SV_TARGET
{
    float4 vpos;
    float depth;

    float2 uv = IN.uv;

    // position
    depth = SampleZBufferMip(uv, 0);
    float4 spos = float4(mad(uv, 2.0f, -1.0f), 1.0f, 1.0f);
    vpos = mul(_ClipToViewMatrix, spos);
    vpos = float4(vpos.xyz * depth / vpos.w, 1.0f);

    // normal
    float3 wnrm = SampleGBuffer2(uv);
    wnrm = normalize(mad(wnrm, 2.0f, -1.0f));
    float3 vnrm = mul(_WorldToViewMatrix, wnrm);
    float3 vdir = normalize(-vpos.xyz);

    if (-vpos.z > _SSAOFadeDepth)
    {
        discard;
    }

    float3 noise = SampleNoise(uv);

    ray ray;
    ray.uv = uv;
    ray.pos = vpos;
    ray.noise = noise;

    ray.r = max(_SSAORayLength, 0.001f);
    ray.t = max(_SSAOMeanDepth, 0.001f);

    // convert to linear 0-1 depth
    ray.t = saturate((ray.t - _ProjectionParams.y) / (_ProjectionParams.z - _ProjectionParams.y));

    float slice = UNITY_PI / _SSAONumSample;

    float div = 0.0f;
    float4 ao = 0.0f;

    uint2 coord = uint2(uv * _ScreenParams.xy);

    #if defined(_SSAOSubSample_1)
        uint i0 = (coord.x + coord.y) % 2;
        uint di = 2;
    #elif defined(_SSAOSubSample_2)
        uint i0 = (coord.x % 2) + 2 * (coord.y % 2);
        uint di = 4;
    #else
        uint i0 = 0;
        uint di = 1;
    #endif
    
    [unroll]
    for (uint iter = i0; iter < _SSAONumSample; iter += di)
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

        HorizonTrace(ray, theta, mask);
        
        float4 vec = DecodeVisibility(vdir, ray.dir.xyz, theta.x, mask);

        ao.xyz += vec.xyz;
        ao.w += vec.w * length(proj);
        div += length(proj);
    }

    ao.xyz = normalize(ao.xyz);
    ao.xyz = mul(_ViewToWorldMatrix, ao.xyz);
    ao.xyz = mad(ao.xyz, 0.5f, 0.5f);
    ao.w  = saturate(ao.w / div);
    ao.w = pow(lerp(_SSAOLightBias, 1.0f, ao.w), _SSAOIntensity);

    return ao;
}

inline void ApplyOcclusionMRT(v2f_mrt IN, out half4 mrt0: SV_TARGET0, out half4 mrt1:SV_TARGET1)
{
    float4 vpos, wpos;

    SampleCoordinates(IN.uv, vpos, wpos);

    float3 wnrm = SampleGBuffer2(IN.uv);
    wnrm = normalize(mad(wnrm, 2.0f, -1.0f));
    float3 vnrm = mul(_WorldToViewMatrix, wnrm);
    float3 vdir = normalize(-vpos.xyz);
    vdir = mul(_ViewToWorldMatrix, vdir);
    
    half4 mask = SampleMask(IN.uv);
    half4 diffuse = SampleGBuffer3(IN.uv);
    half4 specular = SampleReflection(IN.uv);

    if (-vpos.z < _SSAOFadeDepth)
    {
        //
        // diffuse occlusion
        //
        half ao = mask.w;

        // specular occlusion
        half roughness = saturate(1.0f - SampleGBuffer1(IN.uv).w);
        roughness *= roughness;

        half4 angle;
        // reflection apature angle
        angle.x = FastArcCos(exp2(-3.32193f * roughness));
        // occlusion apature angle
        angle.y = FastArcCos(FastSqrt(1.0f - ao));
        // absolute angle difference
        angle.z = abs(angle.x - angle.y);
        // angle between bentnormal and reflection vector
        angle.w = FastArcCos(dot(mask.xyz, reflect(-vdir, wnrm)));

        half intersection = smoothstep(0.0f, 1.0f, 1.0f - saturate((angle.w - angle.z) / (angle.x + angle.y - angle.z)));
        half so = lerp(0.0f, intersection, saturate((angle.y - 0.1f) * 5.0f));

        // fade
        half fade = smoothstep(0.8f * _SSAOFadeDepth, _SSAOFadeDepth, -vpos.z);

        ao = lerp(ao, 1.0f, fade);
        so = lerp(so, 1.0f, fade);

        // multi-bounce occlusion
    #ifdef _MULTIBOUNCE_OCCLUSION
        half3 albedo = SampleGBuffer0(IN.uv).xyz;

        half3 a =  2.0404f * albedo - 0.3324f;
        half3 b = -4.7951f * albedo + 0.6417f;
        half3 c =  2.7552f * albedo + 0.6903f;

        half3 vis = max(ao, mad(mad(ao, a, b), ao, c) * ao);

        mrt0 = half4(diffuse.xyz * vis, diffuse.w);
    #else
        mrt0 = half4(diffuse.xyz * ao, diffuse.w);
    #endif
        mrt1 = half4(specular.xyz * so, specular.w);
    }

    else
    {
        mrt0 = diffuse;
        mrt1 = specular;
    }
}

#endif