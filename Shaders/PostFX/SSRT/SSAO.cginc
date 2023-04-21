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

#define _SSAONumSample 6

#ifndef _SSAONumStride
    #define _SSAONumStride 4
#endif

inline float2 HorizonTrace(ray ray)
{
    uint power = max(1, _SSAOStepPower);
    float2 theta = -10.0f;

    [unroll]
    for (uint iter = 1; iter <= _SSAONumStride; iter ++)
    {
        float str = pow((float) iter / _SSAONumStride, power);

        float4 uv = {
            lerp(ray.org, ray.fwd, str),
            lerp(ray.org, ray.bwd, str)
        };

        float2 z = {
            LinearEyeDepth(SampleZBuffer(uv.xy)),
            LinearEyeDepth(SampleZBuffer(uv.zw))
        };

        float threshold = ray.len * FastSqrt(1.0f - str * str);
        float2 dz = ray.z - z.xy;
        //dz = min(threshold, dz) * step(dz, ray.r * _SSAOMeanDepth);

        dz = min(threshold, dz) * step(dz, ray.r * _SSAOMeanDepth);
        dz /= abs(str * ray.len);

        theta = max(theta, dz);
    }

    return FastArcTan(theta);
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
        // ao
        float slice = FULL_PI / _SSAONumSample;
        float angle = FastArcCos(dot(vnrm, vdir));

        ray ray;

        uint block = max(1, _SSAOBlockSize);
        
        float2 suv = trunc(IN.uv * _MainTex_TexelSize.zw / block) * _MainTex_TexelSize.xy * block;

        ray.z = depth;
        ray.org = IN.uv;
        ray.len = mad(GradientNoise(suv * 1.1f), 0.4f, 0.8f) * _SSAORayLength;
        ray.r = mad(GradientNoise(suv * 1.6f), 0.4h, 0.8h);

        float offset = GradientNoise(suv * 2.1f);

        for (float iter = 0.5f; iter < _SSAONumSample; iter += 1.0f)
        {
            float4 dir = 0.0h;
            sincos((iter + offset) * slice, dir.y, dir.x);
            dir.xyz = normalize(dir.xyz - vdir * dot(dir.xyz, vdir));
            
            float4 spos = mul(unity_CameraProjection, mad(dir, ray.len, vpos));

            ray.fwd = spos.xy / spos.w * 0.5h + 0.5h;
            ray.bwd = mad(ray.org, 2.0f, -ray.fwd);

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

    if (_SSAOMixFactor > 0.0h)
    {
        float2 uvOld = GetAccumulationUv(wpos);
        half4 aoOld = SampleAO(uvOld);
        aoOld.xyz = mad(aoOld.xyz, 2.0h, -1.0h);
        ao = lerp(ao, aoOld, min(_SSAOMixFactor, 0.99h));

        ao.xyz = normalize(ao.xyz);
    }

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

#ifndef KERNEL_STEP
    #define KERNEL_STEP 1
#endif

inline half4 BilateralBlur(v2f_img IN) : SV_TARGET
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
            correction = correction * exp(-abs(zSample - zRef) * 2.0h);
            correction = correction * pow(max(0, dot(nSample, nRef)), 32);
            
            sum += ao * correction;
            norm += correction;
        }
    }

    /*
    for(int iter = -KERNEL_TAPS; iter <= KERNEL_TAPS; iter ++)
    {
        #ifdef _BLUR_DIR_X
            int2 offset = int2(1, 0) * iter;
        #else
            int2 offset = int2(0, 1) * iter;
        #endif

        half4 ao = SampleTexel(IN.uv, offset);
        ao.xyz = mad(ao.xyz, 2.0h, -1.0h);

        half zSample = LinearEyeDepth(SampleZBuffer(IN.uv, offset));
        half3 nSample = mad(SampleGBuffer2(IN.uv, offset), 2.0h, -1.0h);

        half correction = torusKernel[iter + KERNEL_TAPS];
        correction = correction * exp(-abs(zSample - zRef) * 8.0h);
        correction = correction * exp(-distance(nSample, nRef) * 8.0h);

        sum += ao * correction;
        norm += correction;
    }
    */

    sum.xyz = normalize(sum.xyz / norm);
    sum.xyz = mad(sum.xyz, 0.5h, 0.5h);
    sum.w = sum.w / norm;

    return saturate(sum);
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