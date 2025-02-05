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

uniform Texture2D _SSAOFlipRenderTexture;
uniform Texture2D _SSAOFlopRenderTexture;

uniform SamplerState sampler_SSAOFlipRenderTexture;
uniform SamplerState sampler_SSAOFlopRenderTexture;

uniform Texture2D _HierachicalZBuffer0;
uniform Texture2D _HierachicalZBuffer1;
uniform Texture2D _HierachicalZBuffer2;
uniform Texture2D _HierachicalZBuffer3;
uniform Texture2D _HierachicalZBuffer4;

uniform SamplerState sampler_HierachicalZBuffer0;
uniform SamplerState sampler_HierachicalZBuffer1;
uniform SamplerState sampler_HierachicalZBuffer2;
uniform SamplerState sampler_HierachicalZBuffer3;
uniform SamplerState sampler_HierachicalZBuffer4;

uniform float4 _HierachicalZBuffer0_TexelSize;
uniform float4 _HierachicalZBuffer1_TexelSize;
uniform float4 _HierachicalZBuffer2_TexelSize;
uniform float4 _HierachicalZBuffer3_TexelSize;
uniform float4 _HierachicalZBuffer4_TexelSize;

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
    float4 dir;
    float3 noise;
    float r;
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

inline float SampleZBufferMip(float2 uv, uint mip)
{
    if      (mip > 3)   return _HierachicalZBuffer4.Sample(sampler_HierachicalZBuffer4, uv).x;
    else if (mip > 2)   return _HierachicalZBuffer3.Sample(sampler_HierachicalZBuffer3, uv).x;
    else if (mip > 1)   return _HierachicalZBuffer2.Sample(sampler_HierachicalZBuffer2, uv).x;
    else if (mip > 0)   return _HierachicalZBuffer1.Sample(sampler_HierachicalZBuffer1, uv).x;
    else                return _HierachicalZBuffer0.Sample(sampler_HierachicalZBuffer0, uv).x;
}

inline float SampleZBufferLOD(float2 uv, float lod)
{
    if      (lod >= 4.0f)
    {
        return _HierachicalZBuffer4.Sample(sampler_HierachicalZBuffer4, uv).x;
    }

    else if (lod >= 3.0f)
    {
        return _HierachicalZBuffer3.Sample(sampler_HierachicalZBuffer3, uv).x;
    }

    else if (lod >= 2.0f)
    {
        return _HierachicalZBuffer2.Sample(sampler_HierachicalZBuffer2, uv).x;
    }

    else if (lod >= 1.0f)
    {
        return _HierachicalZBuffer1.Sample(sampler_HierachicalZBuffer1, uv).x;
    }

    else
    {
        return _HierachicalZBuffer0.Sample(sampler_HierachicalZBuffer0, uv).x;
    }
}

inline float ZBufferPrePass(v2f_img IN) : SV_TARGET
{
    return Linear01Depth(SampleZBuffer(IN.uv));
}

inline float ZBufferDownSample(v2f_img IN) : SV_TARGET
{
    return dot(_MainTex.Gather(sampler_MainTex, IN.uv), 0.25f);
}

// gram-schmidt process
inline float3x3 GramSchmidtMatrix(float3 axis)
{
	float3 vec = normalize(lerp(float3(1.0f, 0.0f, 0.0f), float3(0.0f, 1.0f, 0.0f), abs(axis.x)));
    float3 tangent = normalize(vec - axis * dot(vec, axis));
    float3 bitangent = normalize(cross(axis, tangent));

    return float3x3(tangent, bitangent, axis);
}

half4 IndirectOcclusion(v2f_img IN) : SV_TARGET
{
    float2 uv = IN.uv;

    float4 vpos;
    float depth;

    // view-space coordinate reconstruction
    depth = SampleZBufferLOD(uv, 0);
    float4 spos = float4(mad(uv, 2.0f, -1.0f), 1.0f, 1.0f);
    vpos = mul(_ClipToViewMatrix, spos);
    vpos = float4(vpos.xyz * depth / vpos.w, 1.0f);

    // world-space and view-space normals
    half3 wnrm = SampleGBuffer2(uv);
    wnrm = normalize(mad(wnrm, 2.0f, -1.0f));
    half3 vnrm = mul(_WorldToViewMatrix, wnrm);

    // view-space view direction
    half3 vdir = half3(0.0h, 0.0h, 1.0h);

    if (-vpos.z > _SSAOFadeDepth)
    {
        discard;
    }

    // noise
    float3 noise = SampleNoise(uv);

    uint power = clamp(_SSAORayStride, 1, 5);

    // normal projection
    float lproj[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
    // horizon angle
    float gamma[8] = { 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f };
    float theta[8] = { 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f };

    // horizon search (spiral sampling)
    float4 vp, sp;
    float2 uvref;

    // reference uv difference
    float aoRadius = max(_SSAORayLength, 0.0001f);

    vp = float4(aoRadius, 0.0f, 0.0f, 0.0f) + vpos;
    sp = mul(unity_CameraProjection, vp);
    uvref.x = sp.x / sp.w * 0.5f + 0.5f - uv.x;

    vp = float4(0.0f, aoRadius, 0.0f, 0.0f) + vpos;
    sp = mul(unity_CameraProjection, vp);
    uvref.y = sp.y / sp.w * 0.5f + 0.5f - uv.y;

    half4 ao = 1.0f;

    // nomal projection plane & default horizon angle
    [unroll]
    for (uint iter = 0; iter < 4; iter ++)
    {
        float3 pdir = 0.0f;
        float rad = QR_PI * ((float)iter - noise.x + 0.5f);

        sincos(rad, pdir.y, pdir.x);

        // normal projection plane
        float3 proj = dot(vnrm, vdir) * vdir + dot(vnrm, pdir) * pdir;
        lproj[iter] = length(proj);
        
        gamma[iter] = acos(normalize(proj).z) * sign(dot(proj, pdir));
        gamma[iter] = clamp(gamma[iter], -HALF_PI, HALF_PI);

        gamma[iter + 4] = -gamma[iter];
        theta[iter    ] = -gamma[iter];
        theta[iter + 4] = +gamma[iter];
    }

    [unroll]
    for (iter = 0; iter < 8; iter ++)
    {
        float2 pdir = 0.0f;
        float phi = QR_PI * ((float)iter - noise.x + 0.5f);
        sincos(phi, pdir.y, pdir.x);

        float2 duv, suv, mix, dz;
        float horizon, dist, z;

        duv = _HierachicalZBuffer0_TexelSize.xy * pdir;

        //
        suv = uv + (1.0f + 6.0f * noise.x) * duv;
        z = SampleZBufferMip(suv, 0);
        sp = float4(mad(suv, 2.0f, -1.0f), 1.0f, 1.0f);
        vp = mul(_ClipToViewMatrix, sp);
        vp = float4(vp.xyz * z / vp.w , 1.0f);

        dz.x = vp.z - vpos.z;
        dz.y = vp.z - vpos.z - _SSAOMeanDepth * mad(noise.z, 1.0f, 0.5f);

        dist = distance(vp.xy, vpos.xy);
        horizon = atan(dz.x / dist);
        theta[iter] = max(horizon, theta[iter]);

        //
        suv = uv + (2.0f + 12.0f * noise.x) * duv;
        z = SampleZBufferMip(suv, 1);
        sp = float4(mad(suv, 2.0f, -1.0f), 1.0f, 1.0f);
        vp = mul(_ClipToViewMatrix, sp);
        vp = float4(vp.xyz * z / vp.w , 1.0f);

        dz.x = vp.z - vpos.z;
        dz.y = vp.z - vpos.z - _SSAOMeanDepth * mad(noise.z, 1.0f, 0.5f);

        dist = distance(vp.xy, vpos.xy);
        horizon = atan(dz.x / dist);
        theta[iter] = max(horizon, theta[iter]);
    }

    // spiral tracing to maximum horizon
    [unroll]
    for (iter = 0; iter < _SSAONumStride; iter ++)
    {
        // sampling lod
        float lod = 0.125f * iter + 1.0f;

        // vogel disc sampling
        float t = 2.4f * (float)iter + 4.0f * noise.x * UNITY_PI;
        float r = ((float)iter + 0.5f) / (float)_SSAONumStride;
        r = pow(r, power);

        float2 pdir = 0.0f;
        sincos(t, pdir.y, pdir.x);

        // minimum uv difference (one pixel)
        float2 muv = pdir;

        if      (lod >= 4.0f)   muv *= _HierachicalZBuffer4_TexelSize.xy;
        else if (lod >= 3.0f)   muv *= _HierachicalZBuffer3_TexelSize.xy;
        else if (lod >= 2.0f)   muv *= _HierachicalZBuffer2_TexelSize.xy;
        else if (lod >= 1.0f)   muv *= _HierachicalZBuffer1_TexelSize.xy;
        else                    muv *= _HierachicalZBuffer0_TexelSize.xy;

        float2 duv = uvref * r * pdir + muv;
        //duv = length(duv) > length(muv) ? duv : muv;
        //if (abs(uvref.x) > abs(duv.x) && abs(uvref.y) > abs(duv.y))
        {
            float2 suv = uv + duv;

            // depth sampling
            float z = SampleZBufferLOD(suv, lod);

            // reconstruct view-space sampling coordinate
            sp = float4(mad(suv, 2.0f, -1.0f), 1.0f, 1.0f);
            vp = mul(_ClipToViewMatrix, sp);
            vp = float4(vp.xyz * z / vp.w , 1.0f);
        
            // get horizon angle
            float2 dz = {
                // front face
                vp.z - vpos.z,
                // back face
                vp.z - vpos.z - _SSAOMeanDepth * mad(noise.z, 1.0f, 0.5f)
            };

            // hemisphere threshold
            float h = sqrt(1.0f - r * r);
            float threshold = atan(h / r);

            float horizon = atan(dz.x / distance(vp.xy, vpos.xy));

            // get directional index
            uint idx = (uint)(t / (UNITY_PI * 0.25f) + noise.x);
            idx = idx % 8;

            // update horizon angle
            theta[idx] = max(horizon, theta[idx]);
        }
    }

    // gtao function
    [unroll]
    for (iter = 0; iter < 4; iter ++)
    {
        float2 t = {theta[iter], theta[iter + 4]};
        float g = gamma[iter];

        t.x = min(HALF_PI - t.x, HALF_PI + g);
        t.y = max(t.y - HALF_PI, g - HALF_PI);

        // visibility calculation
        half vis = 0.0h;
        vis += 0.25f * (2.0f * t.x * sin(g) + cos(g) - cos(2.0f * t.x - g));
        vis += 0.25f * (2.0f * t.y * sin(g) + cos(g) - cos(2.0f * t.y - g));

        ao.w += vis * lproj[iter];
    }

    ao.xyz = normalize(ao.xyz);
    ao.xyz = mul(_ViewToWorldMatrix, ao.xyz);
    ao.xyz = mad(ao.xyz, 0.5f, 0.5f);
    ao.w = saturate(ao.w * 0.25f);
    ao.w = pow(lerp(_SSAOLightBias, 1.0f, ao.w), _SSAOIntensity);

    return ao;
}

void HorizonTrace(ray ray, inout float4 theta)
{
    float2 duv = ray.dir.xy * _HierachicalZBuffer0_TexelSize.xy;
    float2 backFace = ray.r * sin(theta.zw);

    [unroll]
    for (uint iter = 1; iter < 3; iter ++)
    {
        float2x2 uv = {
            ray.org + (1.0f + 6.0f * ray.noise.x) * (float)iter * duv,
            ray.org - (1.0f + 6.0f * ray.noise.x) * (float)iter * duv
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
            SampleZBufferMip(uv[0], iter - 1),
            SampleZBufferMip(uv[1], iter - 1)
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

        dz -= ray.vp.z;
        dz.zw -= ray.t;
        dz.xy = min(dz.xy, ray.r.xx);
        float2 horizon = atan(dz.xy / r.xy);
        float2 mix = smoothstep(backFace, ray.r.xx, dz.zw);
        horizon = lerp(horizon, theta.zw, mix);
        theta.xy = ray.r.xx > r ? max(theta.xy, horizon) : theta.xy;
    }

    uint power = max(1, min(4, _SSAORayStride));

    [unroll]
    for (iter = 0; iter < _SSAONumStride; iter ++)
    {
        float str = pow(((float) iter + 1.0f) / _SSAONumStride, power);

        float2x2 uv = {
            mad(ray.fwd, str, ray.org + 10.0f * duv[0]),
            mad(ray.bwd, str, ray.org + 10.0f * duv[1])
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
            SampleZBufferMip(uv[0], iter + 2),
            SampleZBufferMip(uv[1], iter + 2)
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

        dz -= ray.vp.z;
        dz.zw -= ray.t;
        dz.xy = min(dz.xy, ray.r.xx);
        float2 horizon = atan(dz.xy / r.xy);
        float2 mix = smoothstep(backFace, ray.r.xx, dz.zw);
        horizon = lerp(horizon, theta.zw, mix);
        theta.xy = ray.r.xx > r ? max(theta.xy, horizon) : theta.xy;
    }
}

half4 vIndirectOcclusion(v2f_img IN) : SV_TARGET
{
    float4 vpos;
    float depth;

    // interleaved uv
    float2 uv = IN.uv;

    if (_SSAOSubSample == 1)
    {
        uint2 coord = round((uv - 0.5f * _MainTex_TexelSize.xy) * _MainTex_TexelSize.zw);
	    coord.x = coord.y % 2 == _FrameCount % 2 ? 2 * coord.x : 2 * coord.x + 1;
        uv = ((float2) coord + 0.5f) * _MainTex_TexelSize.xy;
        if (uv.x > 1.0f) discard;
    }

    else if (_SSAOSubSample == 2)
    {
        uint2 coord = round((uv - 0.5f * _MainTex_TexelSize.xy) * _MainTex_TexelSize.zw);
        coord = 2 * coord + uint2((_FrameCount % 4) / 2, (_FrameCount % 4) % 2);
	    uv = ((float2) coord + 0.5f) * _MainTex_TexelSize.xy;
        if (uv.x > 1.0f || uv.y > 1.0f) discard;
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

    if (-vpos.z > _SSAOFadeDepth)
    {
        return half4(mad(wnrm, 0.5h, 0.5h), 1.0h);
    }

    float3 noise = SampleNoise(uv);

    ray ray;
    ray.vp = vpos;
    ray.org = uv;
    ray.noise = noise;

    ray.r = max(_SSAORayLength, 0.001f) * mad(noise.x, 1.0f, 0.5f);
    ray.t = max(_SSAOMeanDepth, 0.001f) * mad(noise.y, 1.0f, 0.5f);

    float slice = UNITY_PI / _SSAONumSample;
    half4 ao = 0.0h;

    for (float iter = 0.5f; iter < _SSAONumSample; iter += 1.0f)
    {
        //float4 pdir = 0.0f;
        ray.dir = 0.0f;
        sincos((iter - noise.z) * slice, ray.dir.y, ray.dir.x);
        float4 spos = mul(unity_CameraProjection, mad(ray.r, ray.dir, vpos));
        float2 duv = spos.xy / spos.w * 0.5f + 0.5f - uv;

        ray.fwd = +duv;
        ray.bwd = -duv;

        // normal projection plane
        float3 proj = dot(vnrm, vdir) * vdir + dot(vnrm, ray.dir.xyz) * ray.dir.xyz;
        float gamma = clamp(acos(normalize(proj).z) * sign(dot(proj, ray.dir.xyz)), -HALF_PI, HALF_PI);

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
        ao.xyz += normalize(vdir * cos(bentAngle) + ray.dir.xyz * sin(bentAngle)) * occlusion;
    }

    half fade = smoothstep(0.9 * _SSAOFadeDepth, _SSAOFadeDepth, -vpos.z);

    ao.w = saturate(ao.w / _SSAONumSample);
    ao.w = pow(lerp(_SSAOLightBias, 1.0h, ao.w), _SSAOIntensity);
    ao.w = lerp(ao.w, 1.0h, fade);

    ao.xyz = lerp(ao.xyz, vnrm.xyz, fade);
    ao.xyz = normalize(ao.xyz);
    ao.xyz = mul(_ViewToWorldMatrix, ao.xyz);
    ao.xyz = mad(ao.xyz, 0.5h, 0.5h);

    return ao;
}

inline half4 DecodeAO(v2f_img IN) : SV_TARGET
{
    float2 uv = IN.uv;
    uint2 coord = round((uv - 0.5f * _MainTex_TexelSize.xy) * _MainTex_TexelSize.zw);

    if (_SSAOSubSample == 1)
    {
        if ((coord.x + coord.y) % 2 != _FrameCount % 2)
        {
            return 0.0h;
        }

        else
        {
            coord.x = coord.x / 2;
            uv = ((float2) coord + 0.5f) * _MainTex_TexelSize.xy;

            return SampleTexel(uv);
        }
    }

    else if (_SSAOSubSample == 2)
    {
        uint2 offset = uint2((_FrameCount % 4) / 2, (_FrameCount % 4) % 2);

        if (coord.x % 2 == offset.x && coord.y % 2 == offset.y)
        {
            coord = (coord - offset) / 2;
            uv = ((float2) coord + 0.5f) * _MainTex_TexelSize.xy;
            return SampleTexel(uv);
        }

        else
        {
            return 0.0h;
        }
    }

    else
    {
        return SampleTexel(uv);
    }
}

inline half4 Interpolate(v2f_img IN) : SV_TARGET
{
    float2 uv = IN.uv;
    uint2 coord = round((uv - 0.5f * _MainTex_TexelSize.xy) * _MainTex_TexelSize.zw);
    half4 ao = 0.0h;

    if (_SSAOSubSample == 1)
    {
        if ((coord.x + coord.y) % 2 == _FrameCount % 2)
        {
            ao = SampleTexel(uv);
        }

        else
        {
            half4x4 tex = {
                SampleTexel(uv, int2(-1,  0)),
                SampleTexel(uv, int2( 1,  0)),
                SampleTexel(uv, int2( 0, -1)),
                SampleTexel(uv, int2( 0,  1))
            };

            float4 z = {
                LinearEyeDepth(SampleZBuffer(uv, int2(-1,  0))),
                LinearEyeDepth(SampleZBuffer(uv, int2( 1,  0))),
                LinearEyeDepth(SampleZBuffer(uv, int2( 0, -1))),
                LinearEyeDepth(SampleZBuffer(uv, int2( 0,  1)))
            };

            z -= LinearEyeDepth(SampleZBuffer(uv));

            half4 ao0 = abs(z.x) < abs(z.y) ? tex[0] : tex[1];
            half4 ao1 = abs(z.z) < abs(z.w) ? tex[2] : tex[3];

            ao = min(abs(z.x), abs(z.y)) < min(abs(z.z), abs(z.w)) ? ao0 : ao1;
        }
    }

    else if (_SSAOSubSample == 2)
    {
        uint2 offset = uint2((_FrameCount % 4) / 2, (_FrameCount % 4) % 2);

        if (coord.x % 2 == offset.x && coord.y % 2 == offset.y)
        {
            ao = SampleTexel(uv);
        }

        else if (coord.x % 2 != offset.x && coord.y % 2 == offset.y)
        {
            half2x4 tex = {
                SampleTexel(uv, int2(-1, 0)),
                SampleTexel(uv, int2( 1, 0))
            };

            float2 z = {
                LinearEyeDepth(SampleZBuffer(uv, int2(-1, 0))),
                LinearEyeDepth(SampleZBuffer(uv, int2( 1, 0)))
            };

            z -= LinearEyeDepth(SampleZBuffer(uv));

            ao = abs(z.x) < abs(z.y) ? tex[0] : tex[1];
        }

        else if (coord.x % 2 == offset.x && coord.y % 2 != offset.y)
        {
            half2x4 tex = {
                SampleTexel(uv, int2(0, -1)),
                SampleTexel(uv, int2(0,  1))
            };

            float2 z = {
                LinearEyeDepth(SampleZBuffer(uv, int2(0, -1))),
                LinearEyeDepth(SampleZBuffer(uv, int2(0,  1)))
            };

            z -= LinearEyeDepth(SampleZBuffer(uv));

            ao = abs(z.x) < abs(z.y) ? tex[0] : tex[1];
        }

        else
        {
            half4x4 tex = {
                SampleTexel(uv, int2(-1, -1)),
                SampleTexel(uv, int2( 1, -1)),
                SampleTexel(uv, int2(-1,  1)),
                SampleTexel(uv, int2( 1,  1))
            };

            float4 z = {
                LinearEyeDepth(SampleZBuffer(uv, int2(-1, -1))),
                LinearEyeDepth(SampleZBuffer(uv, int2( 1, -1))),
                LinearEyeDepth(SampleZBuffer(uv, int2(-1,  1))),
                LinearEyeDepth(SampleZBuffer(uv, int2( 1,  1)))
            };

            z -= LinearEyeDepth(SampleZBuffer(uv));

            half4 ao0 = abs(z.x) < abs(z.y) ? tex[0] : tex[1];
            half4 ao1 = abs(z.z) < abs(z.w) ? tex[2] : tex[3];

            ao = min(abs(z.x), abs(z.y)) < min(abs(z.z), abs(z.w)) ? ao0 : ao1;
        }
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

    float depth = LinearEyeDepth(SampleZBuffer(IN.uv));
    half4 result = depth > _SSAOFadeDepth ? color : half4(color.rgb, min(color.a, ao));
    return result;
}

inline half4 ApplyOcclusionToGBuffer3(v2f_img IN) : SV_TARGET
{
    half ao = SampleFlip(IN.uv).a;
    half4 color = SampleTexel(IN.uv);

    float depth = LinearEyeDepth(SampleZBuffer(IN.uv));
    half4 result = depth > _SSAOFadeDepth ? color : half4(color.rgb * ao, color.a);
    return result;
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

    half4 result = depth > _SSAOFadeDepth ? color : half4(color.rgb * intersection, color.a);
    return result;
}

inline half4 SpatialDenoiser(v2f_img IN) : SV_TARGET
{
    float4 vpos, wpos;
    float depth;

    SampleCoordinates(IN.uv, vpos, wpos, depth);

    if (depth > _SSAOFadeDepth)
    {
        discard;
    }

    // normal
    half4 wnrm = SampleGBuffer2(IN.uv);
    wnrm = normalize(mad(wnrm, 2.0f, -1.0f));
    half3 vnrm = mul(_WorldToViewMatrix, wnrm.xyz);

    half4 sum = 0.0h;
    half4 div = 0.0h;

    [unroll]
    for (int x = -1; x < 2; x ++)
    {
        [unroll]
        for (int y = -1; y < 2; y ++)
        {
            int2 offset = {x, y};

            half4 tex = SampleTexel(IN.uv, offset);
            tex.xyz = normalize(mad(tex.xyz, 2.0h, -1.0h));

            // material type attenuation
            float mask = SampleGBuffer2(IN.uv, offset).w;
            mask = mask - wnrm.w;
            mask = mask * mask;
            half weight = exp(-128.0f * mask);

            // position attenuation
            float2 uv = IN.uv + offset * _MainTex_TexelSize.xy;
            float z = Linear01Depth(SampleZBuffer(IN.uv, offset));

            float4 sp = float4(mad(uv, 2.0f, -1.0f), 1.0f, 1.0f);
            float4 vp = mul(_ClipToViewMatrix, sp);
            vp = float4(vp.xyz * z / vp.w, 1.0f);

            float3 dir = normalize(vp.xyz - vpos.xyz);

            mask = dot(vnrm, dir);
            mask = mask * mask;
            weight *= exp(-128.0f * mask);

            mask = vp.z - vpos.z;
            mask = mask * mask;
            weight *= exp(-128.0f * mask);

            sum += tex * weight;
            div += weight;
        }
    }

    sum /= div;
    sum.xyz = normalize(sum.xyz);
    sum.xyz = mad(sum.xyz, 0.5h, 0.5h);
    sum.w = saturate(sum.w);

    return saturate(sum);

    /*
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

        half fac = i == 0 ? 1.0h : pow(dot(dir, normalize(vp.xyz - vpos.xyz)), 4);
        fac *= kernel[i + 2];

        half3 nnn = SampleGBuffer2(IN.uv, offset);
        nnn = normalize(mad(nnn, 2.0h, -1.0h));

        fac *= pow(saturate(dot(wnrm, nnn)), 2);

        half4 tex = SampleTexel(IN.uv, offset);

        tex.xyz = normalize(mad(tex.xyz, 2.0h, -1.0h));

        sum += fac * tex;
        div += fac;
    }
    */
}

inline half4 DebugAO(v2f_img IN) : SV_TARGET
{
    return SampleTexel(IN.uv).w;
}

#endif