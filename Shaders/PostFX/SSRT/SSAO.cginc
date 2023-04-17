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

uniform sampler2D _SSGITemporalAOBuffer;

#ifndef _SSAONumSample
    #define _SSAONumSample 4
#endif

#ifndef _SSAONumStride
    #define _SSAONumStride 4
#endif

#ifndef _SSAOKernelStride
    #define _SSAOKernelStride 1
#endif

inline float2 HorizonTrace(ray ray)
{
    // stochastic thickness
    float r = mad(GradientNoise(mad(ray.org, 2.8f, _Time.xx)), 0.4h, 0.8h);

    uint power = max(1, _SSAOStepPower);
    float2 theta = -10.0f;

    for (uint iter = 1; iter <= _SSAONumStride; iter ++)
    {
        float str = pow((float) iter / _SSAONumStride, power);

        float4 uv = {
            lerp(ray.org, ray.fwd, str),
            lerp(ray.org, ray.bwd, str)
        };

        float2 z = {
            LinearEyeDepth(tex2D(_CameraDepthTexture, uv.xy)),
            LinearEyeDepth(tex2D(_CameraDepthTexture, uv.zw))
        };

        float threshold = ray.len * (1.0f - str * str);
        float2 dz = ray.z - z.xy;

        dz = min(threshold, dz) * step(dz, r * _SSAOMeanDepth);
        theta = max(theta, dz / abs(str * ray.len));
    }

    return atan(theta);
}

inline half IndirectOcclusion(v2f_img IN) : SV_TARGET
{
    // coordinate
    float depth;
    float4 vpos;
    float4 wpos;

    SampleCoordinates(IN, vpos, wpos, depth);

    half ao = 0.0h;

    if (depth < _SSAOFadeDepth)
    {
        // normal
        half3 wnrm = tex2D(_CameraGBufferTexture2, IN.uv);
        wnrm = normalize(mad(wnrm, 2.0f, -1.0f));
        half3 vnrm = mul(_WorldToViewMatrix, wnrm);

        // view direction
        half3 vdir = normalize(-vpos.xyz);

        // ao
        float slice = FULL_PI / _SSAONumSample;
        float angle = acos(dot(vnrm, vdir));

        ray ray;

        ray.z = depth;
        ray.org = IN.uv;
        ray.len = _SSAORayLength * mad(GradientNoise(mad(IN.uv, 2.2f, _Time.xx)), 0.004h, 0.008h);

        float offset = GradientNoise(mad(IN.uv, 2.5f, _Time.xx));

        for (uint iter = 0; iter < _SSAONumSample; iter ++)
        {
            float4 dir = 0.0h;
            sincos((iter + offset) * slice, dir.y, dir.x);
            dir.xyz = normalize(dir.xyz - vdir * dot(dir.xyz, vdir));

            float4 spos = mul(unity_CameraProjection, mad(dir, ray.len, vpos));

            ray.fwd = spos.xy / spos.w * 0.5h + 0.5h;
            ray.bwd = mad(ray.org, 2.0f, -ray.fwd);

            float2 theta = HorizonTrace(ray);
            float gamma = sign(dot(vnrm, dir.xyz)) * angle;

            #ifdef _VISIBILITY_GTAO
                theta = HALF_PI - theta;

                theta.x = gamma + max(theta.x - gamma, -HALF_PI);
                theta.y = gamma + min(-theta.y - gamma, HALF_PI);

                half3 nsp = normalize(cross(vdir, dir.xyz));
                half3 njp = vnrm - nsp * dot(vnrm, nsp);

                ao += length(njp) * dot(0.50h * (2.0h * theta * sin(gamma) + cos(gamma) - cos(2.0h * theta - gamma)), 1.0h);
            #else
                ao += cos(theta.x + gamma) + cos(theta.y - gamma);
            #endif
        }

        // fade
        half falloff = smoothstep(_SSAOFadeDepth * 0.9h, _SSAOFadeDepth, depth);
        ao = lerp(0.5h * ao / _SSAONumSample, 1.0h, falloff);
    }

    else
    {
        ao = 1.0h;
    }

    return saturate(ao);

    /*
    if (_SSAOMixFactor > 0.0h)
    {
        half2 uvOld = GetAccumulationUv(wpos);
        half aoOld = tex2D(_SSGITemporalAOBuffer, uvOld);

        ao = lerp(ao, aoOld, min(_SSAOMixFactor, 0.99h));
    }
    return saturate(ao);
    */
}

inline half4 ApplyOcclusionToGBuffer0(v2f_img IN) : SV_TARGET
{
    half ao = tex2D(_SSGITemporalAOBuffer, IN.uv);
    ao = pow(lerp(_SSAOLightBias, 1.0h, ao), _SSAOIntensity);
    half4 color = tex2D(_CameraGBufferTexture0, IN.uv);
    return half4(color.rgb, min(color.a, ao));
}

inline half4 ApplyOcclusionToGBuffer3(v2f_img IN) : SV_TARGET
{
    half ao = tex2D(_SSGITemporalAOBuffer, IN.uv);
    ao = pow(lerp(_SSAOLightBias, 1.0h, ao), _SSAOIntensity);
    half4 color = tex2D(_CameraGBufferTexture3, IN.uv);
    return half4(color.rgb * ao, color.a);
}

inline half BilateralBlur(v2f_img IN) : SV_TARGET
{
    half2 ao = 0.0h;

    half zM = LinearEyeDepth(tex2D(_CameraDepthTexture, IN.uv));
    half3 nM = mad(tex2D(_CameraGBufferTexture2, IN.uv), 2.0h, -1.0h);

    for (uint iter = 0; iter < 9; iter ++)
    {
        half2 dir = normalize(half2(
            GradientNoise(IN.uv * 2.5f),
            GradientNoise(IN.uv * 2.8f)
        ));

        #ifdef _BLUR_DIR_X
            half2 offsetUv = IN.uv + _MainTex_TexelSize.xy * half2(0.0h, 1.0h) * blurKernel[iter].x;
        #else
            half2 offsetUv = IN.uv + _MainTex_TexelSize.xy * half2(1.0h, 0.0h) * blurKernel[iter].x;
        #endif

        half aoS = tex2D(_MainTex, offsetUv);

        // depth correction factor
        half zS = LinearEyeDepth(tex2D(_CameraDepthTexture, offsetUv));
        // normal correction factor
        half3 nS = mad(tex2D(_CameraGBufferTexture2, offsetUv), 2.0h, -1.0h);
        // correction factor
        half s = exp(-abs(zS - zM) * 8.0h) * exp(-distance(nS, nM) * 8.0h);

        ao.x += aoS * blurKernel[iter].y * s;
        ao.y += blurKernel[iter].y * s;
    }

    return saturate(ao.x / ao.y);
}

#endif