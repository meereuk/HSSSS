#ifndef HSSSS_SSAO_CGINC
#define HSSSS_SSAO_CGINC

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

#define _SSAONumSample 4

#ifndef _SSAONumStride
    #define _SSAONumStride 4
#endif

#define KERNEL_TAPS 1

#ifndef KERNEL_STEP
    #define KERNEL_STEP 1
#endif

static const half torusKernel[3] =
{
    0.3h,
    0.4h,
    0.3h
};

struct ray
{
    float2 org;
    float2 fwd;
    float2 bwd;
    float2 len;
    float z;
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

inline float2 HorizonTrace(ray ray, float gamma, uint split)
{
    uint power = max(1, _SSAORayStride);
    float minStr = length(_MainTex_TexelSize.xy / split) / length(ray.fwd - ray.org);
    float2 theta = -1.0f;

    float s = -1.0f;

    [unroll]
    for (float iter = 1.0f; iter <= _SSAONumStride && iter * minStr <= 1.0f; iter += 1.0f)
    {
        float str = iter / _SSAONumStride;
        str = max(iter * minStr, pow(str, power));

        float4 uv = {
            mad(ray.fwd, str, ray.org),
            mad(ray.bwd, str, ray.org)
        };

        float2 z = {
            SampleTexel(uv.xy).r,
            SampleTexel(uv.zw).r
        };

        float2 threshold = ray.len * FastSqrt(1.0f - str * str);
        float2 dz = (ray.z - z.xy);

        dz = min(threshold, dz) * step(dz, _SSAOMeanDepth * ray.r);
        dz /= abs(str * ray.len);

        theta = max(theta, dz);

        s *= -1.0f;
    }

    return FastArcTan(theta);
}

inline float ZBufferPrePass(v2f_img IN) : SV_TARGET
{
    uint split = max(min(exp2(_SSAOScreenDiv), 8), 1);
    float2 uv = EncodeInterleavedUV(IN.uv, _MainTex_TexelSize, split);
    return LinearEyeDepth(SampleZBuffer(uv));
}

inline half4 IndirectOcclusion(v2f_img IN) : SV_TARGET
{
    float4 vpos;
    float4 wpos;
    float depth;

    // interleaved uv
    uint split = max(min(exp2(_SSAOScreenDiv), 8), 1);
    float2 uv = EncodeInterleavedUV(IN.uv, _MainTex_TexelSize, split);
    SampleCoordinates(uv, vpos, wpos, depth);

    // normal
    half3 wnrm = SampleGBuffer2(uv);
    wnrm = normalize(mad(wnrm, 2.0f, -1.0f));
    half3 vnrm = mul(_WorldToViewMatrix, wnrm);

    half3 vdir = normalize(-vpos.xyz);

    half4 ao = 0.0h;

    if (depth < _SSAOFadeDepth)
    {
        float idx = GetInterleavedIdx(IN.uv, split);

        ray ray;

        ray.z = depth;
        ray.org = IN.uv;

        ray.len = _SSAORayLength;
        ray.len *= split == 1 ? SampleNoise(IN.uv) + 0.5f : idx + 0.5f;

        ray.r = split == 1 ? SampleNoise(IN.uv + 0.4f) + 0.5f : idx + 0.5f;

        float slice = FULL_PI / _SSAONumSample;
        float angle = FastArcCos(dot(vnrm, vdir));
        float offset = split == 1 ? SampleNoise(IN.uv + 0.2f) : idx;

        for (float iter = 0.5f; iter < _SSAONumSample; iter += 1.0f)
        {
            float4 dir = 0.0h;
            sincos((iter - offset) * slice, dir.y, dir.x);
            dir.xyz = normalize(dir.xyz - vdir * dot(dir.xyz, vdir));

            float4 spos = mul(unity_CameraProjection, mad(dir, ray.len.x, vpos));
            float2 duv = spos.xy / spos.w * 0.5f + 0.5f;
            duv = (duv - uv) / split;
            
            //ClampInterleavedUV(ray.org, duv, ray.fwd, ray.bwd, ray.len, split);

            ray.fwd = +duv;
            ray.bwd = -duv;

            float gamma = sign(dot(vnrm, dir.xyz)) * angle;
            float2 theta = HorizonTrace(ray, gamma, split);

            #ifdef _VISIBILITY_GTAO
                float3 nsp = normalize(cross(dir.xyz, vdir));
                float3 njp = vnrm - nsp * dot(vnrm, nsp);

                theta = HALF_PI - theta;
                
                theta.x = gamma + max(theta.x - gamma, -HALF_PI);
                theta.y = gamma + min(-theta.y - gamma, HALF_PI);

                float bentAngle = 0.5h * (theta.x + theta.y);

                ao.xyz += vdir * cos(bentAngle) + dir.xyz * sin(bentAngle);

                ao.w += length(njp) * dot((2.0h * theta * sin(gamma) + cos(gamma) - cos(2.0h * theta - gamma)), 0.5h);
            #else
                ao.w += cos(theta.x + gamma) + cos(theta.y - gamma);

                float3 nsp = normalize(cross(dir.xyz, vdir));
                float3 njp = vnrm - nsp * dot(vnrm, nsp);

                theta = HALF_PI - theta;
                theta.x = gamma + max(theta.x - gamma, -HALF_PI);
                theta.y = gamma + min(-theta.y - gamma, HALF_PI);

                float bentAngle = 0.5h * (theta.x + theta.y);

                ao.xyz += vdir * cos(bentAngle) + dir.xyz * sin(bentAngle);
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

inline half4 DeinterleaveAO(v2f_img IN) : SV_TARGET
{
    uint split = max(min(exp2(_SSAOScreenDiv), 8), 1);
    float2 uv = DecodeInterleavedUV(IN.uv, _MainTex_TexelSize, split);
    return SampleTexel(uv);
}

inline half4 ApplyOcclusionToGBuffer0(v2f_img IN) : SV_TARGET
{
    half ao = SampleFlop(IN.uv).a;
    half4 color = SampleTexel(IN.uv);
    return half4(color.rgb, min(color.a, ao));
}

inline half4 ApplyOcclusionToGBuffer3(v2f_img IN) : SV_TARGET
{
    half ao = SampleFlop(IN.uv).a;
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

    float3 vdir = normalize(_WorldSpaceCameraPos.xyz - wpos.xyz);

    half3 wnrm = SampleGBuffer2(IN.uv).xyz;
    wnrm = normalize(mad(wnrm, 2.0f, -1.0f));

    half4 ao = SampleFlop(IN.uv);
    //half4 ao = SampleAO(IN.uv);
    //ao.xyz = mad(ao.xyz, 2.0h, -1.0h);

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

    return intersection * SampleTexel(IN.uv);
}

inline half4 SpatialDenoiser(v2f_img IN) : SV_TARGET
{
    half4 sum = 0.0h;
    half norm = 0.0h;

    half zRef = LinearEyeDepth(SampleZBuffer(IN.uv));
    half3 nRef = mad(SampleGBuffer2(IN.uv), 2.0h, -1.0h);

    for(int x = -KERNEL_TAPS; x <= KERNEL_TAPS; x ++)
    {
        for(int y = -KERNEL_TAPS; y <= KERNEL_TAPS; y ++)
        {
            float2 offset = _MainTex_TexelSize.xy * float2(x, y) * KERNEL_STEP;
            //int2 offset = int2(x, y) * KERNEL_STEP;

            half4 ao = SampleTexel(IN.uv + offset);
            ao.xyz = mad(ao.xyz, 2.0h, -1.0h);

            half zSample = LinearEyeDepth(SampleZBuffer(IN.uv + offset));
            half3 nSample = mad(SampleGBuffer2(IN.uv + offset), 2.0h, -1.0h);

            half correction = torusKernel[x + KERNEL_TAPS] * torusKernel[y + KERNEL_TAPS];
            correction = correction * exp(-abs(zSample - zRef) * 4.0h * KERNEL_STEP);
            correction = correction * pow(max(0, dot(nSample, nRef)), 32 * KERNEL_STEP);
            
            sum += ao * correction;
            norm += correction;
        }
    }

    sum.xyz = normalize(sum.xyz / norm);
    sum.xyz = mad(sum.xyz, 0.5h, 0.5h);
    sum.w = sum.w / norm;

    return saturate(sum);
}

inline half4 DebugAO(v2f_img IN) : SV_TARGET
{
    return SampleTexel(IN.uv).w;
    //float2 uv = GetStochasticUV(IN.uv, _MainTex_TexelSize, 2);
    //return SampleNoise(uv + frac(_Time.xx));
}

#endif