#ifndef HSSSS_SSAO_CGINC
#define HSSSS_SSAO_CGINC

#include "Common.cginc"

uniform half _SSGIRayLength;
uniform half _SSGIIntensity;
uniform half _SSGIDepthFade;
uniform half _SSGIMixFactor;
uniform half _SSGIThreshold;

#ifndef _SSGINumSample
    #define _SSGINumSample 8
#endif

#ifndef _SSGINumStride
    #define _SSGINumStride 16
#endif

#ifndef _SSGIKernelStride
    #define _SSGIKernelStride 1
#endif

inline void RayTraceIteration(inout ray ray)
{
    // ray position and direction in view space
    half4 vpos = mul(_WorldToViewMatrix, ray.pos);
    half4 vdir = mul(_WorldToViewMatrix, ray.dir);

    // length rescaling
    ray.len = mad(vdir.z, ray.len, vpos.z) > _ProjectionParams.y ?
        -(vpos.z + _ProjectionParams.z) / vdir.z : ray.len;

    [unroll]
    for (uint iter = 1; iter <= _SSGINumStride && ray.hit == false; iter ++)
    {
        ray.step = (half) iter / _SSGINumStride;

        half4 vp = vpos + vdir * ray.len * ray.step;
        half4 sp = mul(unity_CameraProjection, vp);

        ray.uv = sp.xy / sp.w * 0.5h + 0.5h;

        half zRay = -vp.z;
        half zFace = LinearEyeDepth(tex2D(_CameraDepthTexture, ray.uv));
        half zBack = max(tex2D(_BackFaceDepthBuffer, ray.uv), zFace + 0.1h);

        if (zRay > (zFace - 0.2h * ray.step)  && zRay < (zBack + 0.2h * ray.step))
        {
            ray.hit = true;
        }
    }
}

inline half3 DiffuseBRDF(ray ray, half3 normal)
{
    // first occlusion
    half3 first = tex2D(_CameraGBufferTexture3, ray.uv);
    // secondary and more
    half3 second = tex2D(_SSGITemporalGIBuffer, ray.uv) * tex2D(_CameraGBufferTexture0, ray.uv);
    // n dot l
    half ndotl = saturate(dot(ray.dir.xyz, normal));
    // reverse square
    half atten = 1.0h / pow(ray.len * ray.step + 1.0h, 2.0h);

    return (first + second) * atten * ndotl;
}

inline half4 IndirectDiffuse(v2f_img IN) : SV_TARGET
{
    half depth;
    half4 vpos;
    half4 wpos;

    SampleCoordinates(IN, vpos, wpos, depth);

    half3 gi = 0.0h;

    if (depth < _SSGIDepthFade)
    {
        half4 wnrm = tex2D(_CameraGBufferTexture2, IN.uv);
        wnrm.xyz = normalize(mad(wnrm.xyz, 2.0h, -1.0h));

        half4 bnrm = tex2D(_SSGITemporalAOBuffer, IN.uv);
        bnrm.xyz = normalize(mad(bnrm.xyz, 2.0h, -1.0h));

        half3x3 tbn = GramSchmidtMatrix(IN.uv, bnrm.xyz);

        uint idx = (uint) 16.0h * GradientNoiseAlt(IN.uv + _Time.yz);
        half3 dir = hemiSphere[idx];
        dir = normalize(half3(dir.xy * bnrm.a, dir.z));
        dir = mul(dir, tbn);

        //offset = mul(offset, tbn);

        ray ray;
        ray.hit = false;
        ray.len = _SSGIRayLength;
        ray.pos = wpos + half4(wnrm.xyz * 0.01h, 0.0h);
        ray.dir = half4(dir, 0.0h);//half4(normalize(bnrm.xyz + offset), 0.0h);

        RayTraceIteration(ray);

        gi += ray.hit ? DiffuseBRDF(ray, wnrm) : 0.0h;
        gi *= bnrm.a;
    }


    /*
    half3 gi = 0.0h;
    half len = _SSGIRayLength * mad(GradientNoiseAlt(IN.uv + _Time.yz), 0.5f, 0.5f);

    ray ray;
    ray.pos = wpos + half4(wnrm.xyz * 0.01f, 0.0f);

    if (depth < _SSGIDepthFade)
    {
        for (uint iter = 0; iter < _SSGINumSample; iter ++)
        {
            half3 dir = hemiSphere[iter];
            dir = normalize(half3(dir.xy * bnrm.a, dir.z));
            dir = mul(dir, tbn);

            ray.len = len;
            ray.dir = half4(dir, 0.0h);
            ray.hit = false;

            RayTraceIteration(ray);

            gi += ray.hit ? DiffuseBRDF(ray, wnrm) : 0.0h;
        }

        gi = gi * bnrm.a / _SSGINumSample;
    }

    else
    {
        gi = 0.0h;
    }
    */

    half2 uvOld = GetAccumulationUv(wpos);
    half4 giOld = tex2D(_SSGITemporalGIBuffer, uvOld);

    gi = lerp(gi, giOld, _SSGIMixFactor);

    return half4(gi, 1.0h);
}

inline half4 CollectGI(v2f_img IN) : SV_TARGET
{
    half3 ambient = tex2D(_MainTex, IN.uv) * tex2D(_CameraGBufferTexture0, IN.uv);
    half3 direct = tex2D(_CameraGBufferTexture3, IN.uv).rgb;
    return half4(mad(ambient, _SSGIIntensity, direct), 1.0h);
}

inline half4 BilaterlTorusFilter(v2f_img IN) : SV_TARGET
{
    half3 gB = 0.0h;
    half gN = 0.0h;

    half3 gM = tex2D(_MainTex, IN.uv);
    half zM = LinearEyeDepth(tex2D(_CameraDepthTexture, IN.uv));
    half3 nM = mad(tex2D(_CameraGBufferTexture2, IN.uv), 2.0h, -1.0h);

    if (zM < _SSGIDepthFade)
    {
        for(uint i = 0; i < KERNEL_TAPS; i ++)
        {
            for(uint j = 0; j < KERNEL_TAPS; j ++)
            {
                half torus = aTorusKernel[i].y * aTorusKernel[j].y;
                half2 offsetUv = IN.uv + _MainTex_TexelSize.xy * half2(aTorusKernel[i].x, aTorusKernel[j].x) * _SSGIKernelStride;
                
                half3 gS = tex2D(_MainTex, offsetUv);

                half zS = LinearEyeDepth(tex2D(_CameraDepthTexture, offsetUv));
                half3 nS = mad(tex2D(_CameraGBufferTexture2, offsetUv), 2.0h, -1.0h);
                half s = exp(-abs(zS - zM) * 8.0h) * exp(-distance(nS, nM) * 8.0h) * exp(-distance(gS, gM) * 8.0h);

                gB += gS * torus * s;
                gN += torus * s;
            }
        }

        gB /= gN;

        return half4(gB, 1.0h);
    }

    else
    {
        return tex2D(_MainTex, IN.uv);
    }
}

#endif