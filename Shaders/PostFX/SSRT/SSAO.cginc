#ifndef HSSSS_SSAO_CGINC
#define HSSSS_SSAO_CGINC

#include "Common.cginc"

uniform half _SSAOIntensity;
uniform half _SSAOLightBias;
uniform half _SSAORayLength;
uniform half _SSAOMeanDepth;
uniform half _SSAOFadeDepth;
uniform half _SSAOMixFactor;
uniform uint _SSAOStepPower;
uniform uint _SSAOBlockSize;

#define _SSAONumSample 4

#ifndef _SSAONumStride
    #define _SSAONumStride 4
#endif

#ifndef KERNEL_STEP
    #define KERNEL_STEP 1
#endif

struct ray
{
    float2 org;
    float2 fwd;
    float2 bwd;
    float len;
    float z;
    float r;
};

inline float2 HorizonTrace(ray ray)
{
    uint power = max(1, _SSAOStepPower);
    float minStr = length(_ScreenParams.zw - 1.0f) / length(ray.fwd - ray.org);
    float2 theta = -1.0f;

    [unroll]
    for (float iter = 1.0f; iter <= _SSAONumStride && iter * minStr <= 1.0f; iter += 1.0f)
    {
        float str = iter / _SSAONumStride;
        str = max(iter * minStr, pow(str, power));

        float4 uv = {
            lerp(ray.org, ray.fwd, str),
            lerp(ray.org, ray.bwd, str)
        };

        float2 z = {
            LinearEyeDepth(SampleZBuffer(uv.xy)),
            LinearEyeDepth(SampleZBuffer(uv.zw))
        };

        float2 threshold = ray.len * FastSqrt(1.0f - str * str);
        float2 dz = (ray.z - z.xy);

        dz = min(threshold, dz) * step(dz, _SSAOMeanDepth * ray.r);
        dz /= abs(str * ray.len);

        theta = max(theta, dz);
    }

    return FastArcTan(theta);
}

inline float ZBufferPrePass(v2f_img IN) : SV_TARGET
{
    return LinearEyeDepth(SampleZBuffer(IN.uv));
}

inline half4 IndirectOcclusion(v2f_img IN) : SV_TARGET
{
    // coordinate
    float4 vpos, wpos;
    float depth;

    SampleCoordinates(IN.uv, vpos, wpos, depth);

    // normal
    half3 wnrm = SampleGBuffer2(IN.uv);
    wnrm = normalize(mad(wnrm, 2.0f, -1.0f));
    half3 vnrm = mul(_WorldToViewMatrix, wnrm);

    // view direction
    half3 vdir = normalize(-vpos.xyz);

    // ambient occlusion
    half4 ao = 0.0h;

    if (depth < _SSAOFadeDepth)
    {
        ray ray;

        half mask = SampleAO(IN.uv).w;
        uint split = 1;

        split = mask > 0.500h ? 2 : split;
        split = mask > 0.750h ? 4 : split;
        split = mask > 0.875h ? 8 : split;

        float2 uv = GetStochasticUV(IN.uv, _MainTex_TexelSize, split);

        ray.z = depth;
        ray.org = IN.uv;
        ray.len = _SSAORayLength * mad(GradientNoise(uv * 1.6f), 0.8f, 0.6f);
        ray.r = mad(GradientNoise(uv * 1.6f), 0.4f, 0.8f);

        float slice = FULL_PI / _SSAONumSample;
        float angle = FastArcCos(dot(vnrm, vdir));

        float offset = GradientNoise(uv * 2.1f);

        for (float iter = 0.5f; iter < _SSAONumSample; iter += 1.0f)
        {
            float4 dir = 0.0h;
            sincos((iter - offset) * slice, dir.y, dir.x);
            dir.xyz = normalize(dir.xyz - vdir * dot(dir.xyz, vdir));
            
            float4 spos = mul(unity_CameraProjection, mad(dir, ray.len, vpos));
            ray.fwd = spos.xy / spos.w * 0.5h + 0.5h;
            ray.bwd = mad(ray.org, 2.0f, -ray.fwd);
/*
            ray.len.x *= distance(clamp(ray.fwd, 0.0f, 1.0f), ray.org) / distance(ray.fwd, ray.org);
            ray.len.y *= distance(clamp(ray.bwd, 0.0f, 1.0f), ray.org) / distance(ray.bwd, ray.org);

            ray.fwd = clamp(ray.fwd, 0.0f, 1.0f);
            ray.bwd = clamp(ray.bwd, 0.0f, 1.0f);
*/
            float gamma = sign(dot(vnrm, dir.xyz)) * angle;
            float2 theta = HorizonTrace(ray);

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
        half falloff = smoothstep(_SSAOFadeDepth * 0.8h, _SSAOFadeDepth, depth);
        ao = lerp(ao, half4(wnrm, 1.0f), falloff);
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
    return SampleTexel(IN.uv);
}

inline half4 ApplyOcclusionToGBuffer0(v2f_img IN) : SV_TARGET
{
    half ao = SampleAO(IN.uv).a;
    half4 color = SampleTexel(IN.uv);
    return half4(color.rgb, min(color.a, ao));
}

inline half4 ApplyOcclusionToGBuffer3(v2f_img IN) : SV_TARGET
{
    half ao = SampleAO(IN.uv).a;
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

    half4 ao = SampleAO(IN.uv);
    ao.xyz = mad(ao.xyz, 2.0h, -1.0h);

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
        for(int y = -KERNEL_TAPS; y <+ KERNEL_TAPS; y ++)
        {
            int2 offset = int2(x, y) * KERNEL_STEP;

            half4 ao = SampleTexel(IN.uv, offset);
            ao.xyz = mad(ao.xyz, 2.0h, -1.0h);

            half zSample = LinearEyeDepth(SampleZBuffer(IN.uv, offset));
            half3 nSample = mad(SampleGBuffer2(IN.uv, offset), 2.0h, -1.0h);

            half correction = torusKernel[x + KERNEL_TAPS] * torusKernel[y + KERNEL_TAPS];
            correction = correction * exp(-abs(zSample - zRef) * 4.0h);
            correction = correction * pow(max(0, dot(nSample, nRef)), 128);
            
            sum += ao * correction;
            norm += correction;
        }
    }

    sum.xyz = normalize(sum.xyz / norm);
    sum.xyz = mad(sum.xyz, 0.5h, 0.5h);
    sum.w = sum.w / norm;

    return saturate(sum);
}

inline half4 TemporalDenoiser(v2f_img IN) : SV_TARGET
{
    // coordinate
    float4 vpos, wpos;
    half depth;

    SampleCoordinates(IN.uv, vpos, wpos, depth);

    // ambient occlusion history
    float2 uvOld = GetAccumulationUv(wpos);
    float4 wpOld = GetAccumulationPos(uvOld);

    half4 aoOld = SampleAO(uvOld);
    half4 ao = SampleTexel(IN.uv);

    aoOld.xyz = mad(aoOld.xyz, 2.0h, -1.0h);
    ao.xyz = mad(ao, 2.0h, -1.0h);

    if (_SSAOMixFactor > 0.0h)
    {
        float weight = exp(-distance(wpOld, wpos) * 16.0h);
        weight = min(weight * _SSAOMixFactor, 0.96h);

        ao = lerp(ao, aoOld, weight);
    }

    ao.xyz = mad(normalize(ao.xyz), 0.5h, 0.5h);
    return saturate(ao);
}

inline float BlitDepth(v2f_img IN) : SV_TARGET
{
    return SampleZBuffer(IN.uv);
}

inline half4 DebugAO(v2f_img IN) : SV_TARGET
{
    return SampleTexel(IN.uv).w;
}

#endif