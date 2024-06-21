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
uniform bool _SSAOUseSparse;

uniform Texture2D _SSAOFlipRenderTexture;
uniform Texture2D _SSAOFlopRenderTexture;

uniform SamplerState sampler_SSAOFlipRenderTexture;
uniform SamplerState sampler_SSAOFlopRenderTexture;

uniform Texture2D _HierachicalZBuffer0;
uniform Texture2D _HierachicalZBuffer1;
uniform Texture2D _HierachicalZBuffer2;
uniform Texture2D _HierachicalZBuffer3;

uniform SamplerState sampler_HierachicalZBuffer0;
uniform SamplerState sampler_HierachicalZBuffer1;
uniform SamplerState sampler_HierachicalZBuffer2;
uniform SamplerState sampler_HierachicalZBuffer3;

uniform float4 _HierachicalZBuffer0_TexelSize;
uniform float4 _HierachicalZBuffer1_TexelSize;
uniform float4 _HierachicalZBuffer2_TexelSize;
uniform float4 _HierachicalZBuffer3_TexelSize;

#ifndef _SSAONumSample
    #define _SSAONumSample 4
#endif

#ifndef _SSAONumStride
    #define _SSAONumStride 4
#endif

#define beta 8.0f

struct ray
{
    float3 vp;
    float2 org;
    float2 fwd;
    float2 bwd;
    float2 len;
    float t;
};

inline half4 SampleFlip(float2 uv)
{
    half4 ao = _SSAOFlipRenderTexture.Sample(sampler_SSAOFlipRenderTexture, uv);
    ao.xyz = mad(ao.xyz, 2.0h, -1.0h);
    return ao;
}

inline half4 SampleFlop(float2 uv)
{
    half4 ao = _SSAOFlopRenderTexture.Sample(sampler_SSAOFlopRenderTexture, uv);
    ao.xyz = mad(ao.xyz, 2.0h, -1.0h);
    return ao;
}

inline uint GetZBufferLOD(uint iter)
{
    uint lod = 0;

    lod = iter > 1 ? 1 : lod;
    lod = iter > 2 ? 2 : lod;
    lod = iter > 4 ? 3 : lod;

    return lod;
}

inline float SampleZBufferLOD(float2 uv, uint lod)
{
    if (lod == 3)
    {
        return _HierachicalZBuffer3.Sample(sampler_HierachicalZBuffer3, uv).x;
    }

    else if (lod == 2)
    {
        return _HierachicalZBuffer2.Sample(sampler_HierachicalZBuffer2, uv).x;
    }

    else if (lod == 1)
    {
        return _HierachicalZBuffer1.Sample(sampler_HierachicalZBuffer1, uv).x;
    }

    else
    {
        return _HierachicalZBuffer0.Sample(sampler_HierachicalZBuffer0, uv).x;
    }
}

void HorizonTrace(ray ray, inout float4 theta)
{
    uint power = clamp(_SSAORayStride, 1, 5);
    float slope = ray.fwd.y / ray.fwd.x;

    float4 minStr = {
        min(length(_HierachicalZBuffer0_TexelSize.xx * float2(1.0f, slope)),
            length(_HierachicalZBuffer0_TexelSize.yy * float2(1.0f / slope, 1.0f))),
        min(length(_HierachicalZBuffer1_TexelSize.xx * float2(1.0f, slope)),
            length(_HierachicalZBuffer1_TexelSize.yy * float2(1.0f / slope, 1.0f))),
        min(length(_HierachicalZBuffer2_TexelSize.xx * float2(1.0f, slope)),
            length(_HierachicalZBuffer2_TexelSize.yy * float2(1.0f / slope, 1.0f))),
        min(length(_HierachicalZBuffer3_TexelSize.xx * float2(1.0f, slope)),
            length(_HierachicalZBuffer3_TexelSize.yy * float2(1.0f / slope, 1.0f)))
    };

    minStr /= length(ray.fwd);

    float str = max(minStr[0], pow(1.0f / _SSAONumStride, power));

    float2 sum = { 0.0f, 0.0f };
    float2 div = { 0.0f, 0.0f };

    [unroll]
    for (uint iter = 0; iter < _SSAONumStride && str <= 1.0f; iter ++)
    {
        uint lod = iter * 4 / _SSAONumStride;
        str = max(str + minStr[lod], pow(((float) iter + 1.0f) / _SSAONumStride, power));

        float2x2 uv = {
            mad(ray.fwd, str, ray.org),
            mad(ray.bwd, str, ray.org)
        };

        float2x4 sp = {
            { mad(uv[0], 2.0f, -1.0f), 1.0f, 1.0f },
            { mad(uv[1], 2.0f, -1.0f), 1.0f, 1.0f }
        };

        float2x4 vp = {
            mul(_ClipToViewMatrix, sp[0]),
            mul(_ClipToViewMatrix, sp[1])
        };

        float2 z = {
            SampleZBufferLOD(uv[0], lod),
            SampleZBufferLOD(uv[1], lod)
        };


        vp[0] = float4(vp[0].xyz * z.x / vp[0].w , 1.0f);
        vp[1] = float4(vp[1].xyz * z.y / vp[1].w , 1.0f);

        float2 r = {
            distance(vp[0].xy, ray.vp.xy),
            distance(vp[1].xy, ray.vp.xy)
        };

        float4 dz = {
            vp[0].z, vp[1].z,
            vp[0].z, vp[1].z
        };

        dz.zw -= ray.t;
        dz -= ray.vp.z;
        dz /= r.xyxy;

        dz = atan(dz);

        float threshold = atan(sqrt(1.0f - str * str) / str);

        dz.x = lerp(min(dz.x, threshold), theta.z, smoothstep(-threshold, threshold, dz.z));
        dz.y = lerp(min(dz.y, threshold), theta.w, smoothstep(-threshold, threshold, dz.w));

        sum += dz * exp(beta * dz);
        div += exp(beta * dz);

        //theta.x = max(theta.x, lerp(dz.x, theta.x, 0.5f * str));
        //theta.y = max(theta.y, lerp(dz.y, theta.y, 0.5f * str));
    }

    sum /= div;
    theta.xy = sum;
}

inline float ZBufferPrePass(v2f_img IN) : SV_TARGET
{
    return Linear01Depth(SampleZBuffer(IN.uv));
}

inline float ZBufferDownSample(v2f_img IN) : SV_TARGET
{
    return dot(_MainTex.Gather(sampler_MainTex, IN.uv), 0.25f);
}

half4 IndirectOcclusion(v2f_img IN) : SV_TARGET
{
    float4 vpos;
    float depth;

    // interleaved uv
    float2 uv = IN.uv;

    if (_SSAOUseSparse)
    {
        uint2 coord = round((uv - 0.5f * _MainTex_TexelSize.xy) * _MainTex_TexelSize.zw);
	    coord.x = coord.y % 2 == _FrameCount % 2 ? 2 * coord.x : 2 * coord.x + 1;
	    uv = ((float2) coord + 0.5f) * _MainTex_TexelSize.xy;
        if (uv.x > 1.0f) discard;
    }

    depth = SampleZBufferLOD(uv, 0);
    float4 spos = float4(mad(uv, 2.0f, -1.0f), 1.0f, 1.0f);
    vpos = mul(_ClipToViewMatrix, spos);
    vpos = float4(vpos.xyz * depth / vpos.w, 1.0f);

    // normal
    half3 wnrm = SampleGBuffer2(uv);
    wnrm = normalize(mad(wnrm, 2.0f, -1.0f));
    half3 vnrm = mul(_WorldToViewMatrix, wnrm);
    half3 vdir = half3(0.0h, 0.0h, 1.0h);

    if (-vpos.z > _SSAOFadeDepth) discard;

    float3 noise = SampleNoise(uv);

    ray ray;
    ray.vp = vpos;
    ray.org = uv;

    ray.len = max(_SSAORayLength, 0.001f);
    ray.len *= mad(noise.x, 1.0f, 0.5f);
    ray.t = max(_SSAOMeanDepth, 0.001f);
    ray.t *= mad(noise.y, 1.0f, 0.5f);

    float slice = FULL_PI / _SSAONumSample;
    float offset = noise.z;
    float4 pdir = 0.0h;

    half4 ao = 0.0h;
    half dao = 0.0h;

    for (float iter = 0.5f; iter < _SSAONumSample; iter += 1.0f)
    {
        sincos(((float)iter - offset) * slice, pdir.y, pdir.x);

        float4 spos = mul(unity_CameraProjection, mad(pdir, ray.len.x, vpos));
        float2 duv = spos.xy / spos.w * 0.5f + 0.5f;
        duv = (duv - uv);

        ray.fwd = +duv;
        ray.bwd = -duv;

        // normal projection plane
        float3 proj = dot(vnrm, vdir) * vdir + dot(vnrm, pdir.xyz) * pdir.xyz;
        float gamma = clamp(acos(normalize(proj).z) * sign(dot(proj, pdir.xyz)), -HALF_PI, HALF_PI);

        float4 theta = float4(-gamma, gamma, -gamma, gamma);

        HorizonTrace(ray, theta);

        theta.x = min(HALF_PI - theta.x, HALF_PI + gamma);
        theta.y = max(theta.y - HALF_PI, gamma - HALF_PI);

        // ground truth ambient occlusion
        half occlusion = 0.0h;
        occlusion += 0.25h * (2.0h * theta.x * sin(gamma) + cos(gamma) - cos(2.0h * theta.x - gamma));
        occlusion += 0.25h * (2.0h * theta.y * sin(gamma) + cos(gamma) - cos(2.0h * theta.y - gamma));
        occlusion *= length(proj);
        ao.w += occlusion;

        // calculate bent normal
        float bentAngle = 0.5h * (theta.x + theta.y);
        ao.xyz += normalize(vdir * cos(bentAngle) + pdir.xyz * sin(bentAngle)) * occlusion;
    }

    ao.w = saturate(ao.w / _SSAONumSample);
    ao.w = pow(ao.w, _SSAOIntensity);

    ao.xyz = normalize(ao.xyz);
    ao.xyz = mul(_ViewToWorldMatrix, ao.xyz);
    ao.xyz = mad(ao.xyz, 0.5h, 0.5h);

    return ao;
}

inline half4 DecodeAO(v2f_img IN) : SV_TARGET
{
    float2 uv = IN.uv;
    uint2 coord = round((uv - 0.5f * _MainTex_TexelSize.xy) * _MainTex_TexelSize.zw);
    if ((coord.x + coord.y) % 2 != _FrameCount % 2) return 0.0h;
    coord.x = coord.x / 2;
    uv = ((float2) coord + 0.5f) * _MainTex_TexelSize.xy;

    return SampleTexel(uv);
}

inline half4 Interpolate(v2f_img IN) : SV_TARGET
{
    float2 uv = IN.uv;
    uint2 coord = round((uv - 0.5f * _MainTex_TexelSize.xy) * _MainTex_TexelSize.zw);

    half4 ao = 0.0h;

    if ((coord.x + coord.y) % 2 != _FrameCount % 2)
    {
        half4 tex;

        tex = SampleTexel(uv, int2( 1,  0));
        tex.xyz = mad(tex.xyz, 2.0h, -1.0h);
        ao += tex;

        tex = SampleTexel(uv, int2( 0,  1));
        tex.xyz = mad(tex.xyz, 2.0h, -1.0h);
        ao += tex;

        tex = SampleTexel(uv, int2(-1,  0));
        tex.xyz = mad(tex.xyz, 2.0h, -1.0h);
        ao += tex;

        tex = SampleTexel(uv, int2( 0, -1));
        tex.xyz = mad(tex.xyz, 2.0h, -1.0h);
        ao += tex;

        ao.xyz = normalize(ao.xyz);
        ao.xyz = mad(ao.xyz, 0.5h, 0.5h);
        ao.w /= 4.0h;
    }

    else
    {
        ao = SampleTexel(uv);
    }

    return ao;
}

inline half4 ApplyOcclusionToGBuffer0(v2f_img IN) : SV_TARGET
{
    half ao = SampleFlip(IN.uv).a;
    half4 color = SampleTexel(IN.uv);
    return half4(color.rgb, min(color.a, ao));
}

inline half4 ApplyOcclusionToGBuffer3(v2f_img IN) : SV_TARGET
{
    half ao = SampleFlip(IN.uv).a;
    half4 color = SampleTexel(IN.uv);
    return half4(color.rgb * ao, color.a);
}

inline half4 ApplySpecularOcclusion(v2f_img IN) : SV_TARGET
{
    // coordinate
    float depth;
    float4 vpos;
    float4 wpos;

    SampleCoordinates(IN.uv, vpos, wpos, depth);

    float3 vdir = mul(_ViewToWorldMatrix, float4(0.0f, 0.0f, 1.0f, 0.0f));
    //float3 vdir = normalize(_WorldSpaceCameraPos.xyz - wpos.xyz);

    half3 wnrm = SampleGBuffer2(IN.uv).xyz;
    wnrm = normalize(mad(wnrm, 2.0f, -1.0f));

    half4 ao = SampleFlip(IN.uv);

    half roughness = saturate(1.0h - SampleGBuffer1(IN.uv).w);
    roughness *= roughness;

    half4 angle;
    // reflection apature angle
    angle.x = FastArcCos(exp2(-3.32193h * roughness));
    // occlusion apature angle
    angle.y = FastArcCos(FastSqrt(1.0h - ao.w));
    // absolute angle difference
    angle.z = abs(angle.x - angle.y);
    // angle between bentnormal and reflection vector
    angle.w = FastArcCos(dot(ao.xyz, reflect(-vdir, wnrm)));
    //angle.w = acos(dot(ao.xyz, light));

    half intersection = smoothstep(0.0h, 1.0h, 1.0h - saturate((angle.w - angle.z) / (angle.x + angle.y - angle.z)));
    half occlusion = lerp(0.0h, intersection, saturate((angle.y - 0.1h) * 5.0h));

    half4 color = SampleTexel(IN.uv);

    return half4(color.rgb * intersection, color.a);

    return intersection * SampleTexel(IN.uv);
}

inline half4 SpatialDenoiser(v2f_img IN) : SV_TARGET
{
    float4 vpos, wpos;
    float depth;

    SampleCoordinates(IN.uv, vpos, wpos, depth);

    // normal
    half3 wnrm = SampleGBuffer2(IN.uv);
    wnrm = normalize(mad(wnrm, 2.0f, -1.0f));
    half3 vnrm = mul(_WorldToViewMatrix, wnrm);

    half4 sum = 0.0h;
    half4 div = 0.0h;

    half kernel[5] = {
        0.1, 0.2, 0.4, 0.2, 0.1,
    };

    [unroll]
    for (int i = -2; i < 3; i ++)
    {
        #ifdef BLUR_YAXIS
            int2 offset = int2(0, i);
        #else
            int2 offset = int2(i, 0);
        #endif

        float3 dir = normalize(float3(offset, 0.0f));
        dir = normalize(dir - dot(dir, vnrm) * vnrm);

        float2 uv = IN.uv + offset * _MainTex_TexelSize.xy;
        float z = Linear01Depth(SampleZBuffer(IN.uv, offset));

        float4 sp = float4(mad(uv, 2.0f, -1.0f), 1.0f, 1.0f);
        float4 vp = mul(_ClipToViewMatrix, sp);
        vp = float4(vp.xyz * z / vp.w, 1.0f);

        half fac = i == 0 ? 1.0h : pow(dot(dir, normalize(vp.xyz - vpos.xyz)), 2);
        fac *= kernel[i + 2];

        half3 nnn = SampleGBuffer2(IN.uv, offset);
        nnn = normalize(mad(nnn, 2.0h, -1.0h));

        fac *= pow(saturate(dot(wnrm, nnn)), 2);

        half4 tex = SampleTexel(IN.uv, offset);

        tex.xyz = normalize(mad(tex.xyz, 2.0h, -1.0h));

        sum += fac * tex;
        div += fac;
    }

    sum /= div;
    sum.xyz = normalize(sum.xyz);
    sum.xyz = mad(sum.xyz, 0.5h, 0.5h);

    return saturate(sum);
}

inline half4 DebugAO(v2f_img IN) : SV_TARGET
{
    return SampleTexel(IN.uv).w;
}

#endif