#ifndef HSSSS_SSAO_CGINC
#define HSSSS_SSAO_CGINC

#pragma exclude_renderers gles

#include "Common.cginc"

uniform half _SSAOIntensity;
uniform half _SSAOLightBias;
uniform half _SSAORayLength;
uniform uint _SSAORayStride;
uniform half _SSAOMeanDepth;
uniform half _SSAOFadeDepth;
uniform uint _SSAOScreenDiv;

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

#define _SSAONumSample 4

#ifndef _SSAONumStride
    #define _SSAONumStride 4
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
    float3 vp;
    float2 org;
    float2 fwd;
    float2 bwd;
    float2 len;
    float r;
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

inline uint GetZBufferLOD(float iter)
{
    uint lod = 0;

    if (iter <= (_SSAONumStride / 4))
    {
        lod = 0;
    }

    else if (iter <= (_SSAONumStride / 2))
    {
        lod = 1;
    }

    else if (iter <= (_SSAONumStride * 3 / 4))
    {
        lod = 2;
    }

    else
    {
        lod = 3;
    }

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

inline float2 HorizonTrace(ray ray, float gamma)
{
    uint power = max(_SSAORayStride, 1);
    float slope = ray.fwd.y / ray.fwd.x;

    float4 minStr = {
        min(length(_HierachicalZBuffer0_TexelSize.xx * float2(1.0f, slope)), length(_HierachicalZBuffer0_TexelSize.yy * float2(1.0f / slope, 1.0f))),
        min(length(_HierachicalZBuffer1_TexelSize.xx * float2(1.0f, slope)), length(_HierachicalZBuffer1_TexelSize.yy * float2(1.0f / slope, 1.0f))),
        min(length(_HierachicalZBuffer2_TexelSize.xx * float2(1.0f, slope)), length(_HierachicalZBuffer2_TexelSize.yy * float2(1.0f / slope, 1.0f))),
        min(length(_HierachicalZBuffer3_TexelSize.xx * float2(1.0f, slope)), length(_HierachicalZBuffer3_TexelSize.yy * float2(1.0f / slope, 1.0f)))
    };

    minStr /= length(ray.fwd);

    float2 theta = { -gamma, gamma };
    float str = 0.0f;

    [unroll]
    for (float iter = 1.0f; iter <= _SSAONumStride && str <= 1.0f; iter += 1.0f)
    {
        uint lod = GetZBufferLOD(iter);
        str = max(str + minStr[lod], pow(iter / _SSAONumStride, power));

        float2x2 uv = {
            mad(ray.fwd, str, ray.org),
            mad(ray.bwd, str, ray.org)
        };

        [unroll]
        for (uint i = 0; i < 2; i ++)
        {
            float z = SampleZBufferLOD(uv[i], lod);
            float2 duv = uv[i];

            float4 sp = float4(mad(duv, 2.0f, -1.0f), 1.0f, 1.0f);
            float4 vp = mul(_ClipToViewMatrix, sp);
            vp = float4(vp.xyz * z / vp.w, 1.0f);

            float r = distance(vp.xy, ray.vp.xy);
            float t = FastSqrt(max(0.0f, ray.len[i] * ray.len[i] - r * r));

            float2 dz = FastArcTan(float2(vp.z - ray.vp.z, vp.z - ray.vp.z - _SSAOMeanDepth * ray.r) / r);

            //theta[i] = max(theta[i], dz.x);
            theta[i] = dz.y < theta[i] ? max(theta[i], dz.x) : lerp(dz.x, theta[i], saturate((dz.y - theta[i]) / (dz.x - theta[i])));
        }
    }

    //theta = FastArcTan(theta);

    theta.x = min(HALF_PI - theta.x, HALF_PI + gamma);
    theta.y = max(theta.y - HALF_PI, gamma - HALF_PI);

    return theta;
}

inline float ZBufferPrePass(v2f_img IN) : SV_TARGET
{
    return Linear01Depth(SampleZBuffer(IN.uv));
}

inline float ZBufferDownSample(v2f_img IN) : SV_TARGET
{
    return dot(_MainTex.Gather(sampler_MainTex, IN.uv), 0.25f);
}

inline half4 IndirectOcclusion(v2f_img IN) : SV_TARGET
{
    float4 vpos;
    float depth;

    // interleaved uv
    float2 uv = IN.uv;

    uint2 coord = round((uv - 0.5f * _MainTex_TexelSize.xy) * _MainTex_TexelSize.zw);
	coord.x = coord.y % 2 == _FrameCount % 2 ? 2 * coord.x : 2 * coord.x + 1;
	uv = ((float2) coord + 0.5f) * _MainTex_TexelSize.xy;

    if (uv.x > 1.0f) discard;

    depth = SampleZBufferLOD(uv, 0);
    float4 spos = float4(mad(uv, 2.0f, -1.0f), 1.0f, 1.0f);
    vpos = mul(_ClipToViewMatrix, spos);
    vpos = float4(vpos.xyz * depth / vpos.w, 1.0f);

    // normal
    half3 wnrm = SampleGBuffer2(uv);
    wnrm = normalize(mad(wnrm, 2.0f, -1.0f));
    half3 vnrm = mul(_WorldToViewMatrix, wnrm);

    half3 vdir = half3(0.0h, 0.0h, 1.0h);

    half4 ao = 0.0h;

    if (-vpos.z < _SSAOFadeDepth)
    {
        float3 noise = SampleNoise(uv);

        ray ray;
        ray.vp = vpos;
        ray.org = uv;

        ray.len = _SSAORayLength;
        ray.len *= noise.x + 0.5f;

        ray.r = mad(noise.y, 0.4f, 0.8f);

        float slice = FULL_PI / _SSAONumSample;
        float angle = FastArcCos(dot(vnrm, vdir));
        float offset = noise.z;

        for (float iter = 0.5f; iter < _SSAONumSample; iter += 1.0f)
        {
            float4 dir = 0.0h;
            sincos((iter - offset) * slice, dir.y, dir.x);
            dir.xyz = normalize(dir.xyz - vdir * dot(dir.xyz, vdir));

            float4 spos = mul(unity_CameraProjection, mad(dir, ray.len.x, vpos));
            float2 duv = spos.xy / spos.w * 0.5f + 0.5f;
            duv = (duv - uv);

            ray.fwd = +duv;
            ray.bwd = -duv;

            float gamma = sign(dot(vnrm, dir.xyz)) * angle;
            float2 theta = HorizonTrace(ray, gamma);

            float bentAngle = 0.5h * (theta.x + theta.y);
            ao.xyz += vdir * cos(bentAngle) + dir.xyz * sin(bentAngle);

            #ifdef _VISIBILITY_GTAO
                float3 nsp = normalize(cross(dir.xyz, vdir));
                float3 njp = vnrm - nsp * dot(vnrm, nsp);
                ao.w += length(njp) * dot((2.0h * theta * sin(gamma) + cos(gamma) - cos(2.0h * theta - gamma)), 0.5h);
            #else
                ao.w += sin(theta.x - gamma) + sin(gamma - theta.y);
            #endif
        }
        
        ao.xyz = normalize(normalize(ao.xyz) - vdir * 0.5h);
        ao.xyz = mul(_ViewToWorldMatrix, ao.xyz);
        ao.w = 0.5h * ao.w / _SSAONumSample;
        ao.w = pow(lerp(_SSAOLightBias, 1.0h, ao.w), _SSAOIntensity);

        // fade
        half fade = smoothstep(_SSAOFadeDepth * 0.8h, _SSAOFadeDepth, depth);
        ao = lerp(ao, half4(wnrm, 1.0h), fade);
    }

    else
    {
        ao.xyz = wnrm;
        ao.w = 1.0h;
    }

    ao.xyz = normalize(ao.xyz);
    ao.xyz = mad(ao.xyz, 0.5h, 0.5h);

    return saturate(ao);
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
        half4x4 tex = {
            SampleTexel(uv, int2( 0,  1)),
            SampleTexel(uv, int2( 1,  0)),
            SampleTexel(uv, int2( 0, -1)),
            SampleTexel(uv, int2(-1,  0))
        };

        ao.xyz += mad(tex[0].xyz, 2.0h, -1.0h);
        ao.xyz += mad(tex[1].xyz, 2.0h, -1.0h);
        ao.xyz += mad(tex[2].xyz, 2.0h, -1.0h);
        ao.xyz += mad(tex[3].xyz, 2.0h, -1.0h);

        ao.xyz = normalize(ao.xyz);
        ao.xyz = mad(ao.xyz, 0.5h, 0.5h);

        ao.w = min(min(tex[0].w, tex[1].w), min(tex[2].w, tex[3].w));
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
    /*
    float depth = Linear01Depth(SampleZBuffer(IN.uv));

    float4 spos = float4(mad(IN.uv, 2.0f, -1.0f), 1.0f, 1.0f);
    float4 vpos = mul(_ClipToViewMatrix, spos);
    vpos = float4(vpos.xyz * depth / vpos.w, 1.0f);
    */

    float4 vpos, wpos;
    float depth;

    SampleCoordinates(IN.uv, vpos, wpos, depth);

    if (depth > _SSAOFadeDepth)
    {
        return SampleTexel(IN.uv);
    }

    else
    {
        half4 wnrm = SampleGBuffer2(IN.uv);
        wnrm.xyz = normalize(mad(wnrm.xyz, 2.0h, -1.0h));
        half3 vnrm = mul(_WorldToViewMatrix, wnrm.xyz);

        half4 sum = SampleTexel(IN.uv);
        sum.xyz = normalize(mad(sum.xyz, 2.0h, -1.0h));

        half norm = 1.0h;

        [unroll]
        for (int i = 0; i < KERNEL_TAPS; i ++)
        {
            int2 offset = KERNEL_STEP * neighbors[i];
            float2 uv = IN.uv + _MainTex_TexelSize.xy * offset;
            half correction = weights[i];

            half4 ao = SampleTexel(IN.uv, offset);
            ao.xyz = normalize(mad(ao.xyz, 2.0f, -1.0f));

            // geometry aware
            float z = LinearEyeDepth(SampleZBuffer(IN.uv, offset));
            float2 dz = { ddx_fine(z), ddy_fine(z) };

            correction *= exp(-abs(z - depth) / (abs(dot(dz, offset)) + 0.001h));

            // normal aware
            half4 n = SampleGBuffer2(IN.uv, offset);
            n.xyz = normalize(mad(n.xyz, 2.0h, -1.0h));

            correction *= pow(saturate(dot(n.xyz, wnrm.xyz)), 64);
            //correction *= wnrm.w == n.w ? 1.0h : 0.0h;

            sum += ao * correction;
            norm += correction;
        }

        sum /= norm;
        sum.xyz = normalize(sum.xyz);
        sum.xyz = mad(sum.xyz, 0.5h, 0.5h);

        return sum;
    }
}

inline half4 DebugAO(v2f_img IN) : SV_TARGET
{
    /*
    half3 n1 = SampleGBuffer2(IN.uv).xyz;
    half3 n2 = SampleTexel(IN.uv).xyz;
    return dot(mad(n1, 2.0h, -1.0h), mad(n2, 2.0h, -1.0h));
    */
    return SampleTexel(IN.uv).w;
}

#endif