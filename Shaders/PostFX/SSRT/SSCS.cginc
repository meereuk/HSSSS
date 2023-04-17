#ifndef HSSSS_SSCS_CGINC
#define HSSSS_SSCS_CGINC

#include "Common.cginc"

#ifndef _SSCSNumStride
    #define _SSCSNumStride 16
#endif

half3 _LightPosition;
half _SSCSRayLength;
half _SSCSRayRadius;
//half _SSCSFadeDepth;
//half _SSCSMeanDepth;
//half _SSCSDepthBias;

// view-space ray tracing
inline void RayTraceIteration(inout ray ray)
{
    /*
    half4 vpos = mul(_WorldToViewMatrix, ray.pos);
    half4 vdir = mul(_WorldToViewMatrix, ray.dir);

    ray.len = mad(vdir.z, ray.len, vpos.z) > _ProjectionParams.y ?
        -(vpos.z + _ProjectionParams.z) / vdir.z : ray.len;

    [unroll]
    for (uint iter = 1; iter <= _SSCSNumStride && ray.hit == false; iter ++)
    {
        ray.step = (half) iter / _SSCSNumStride;

        half4 vp = vpos + vdir * ray.len * ray.step;
        half4 sp = mul(unity_CameraProjection, vp);

        ray.uv = sp.xy / sp.w * 0.5f + 0.5f;

        half zRay = -vp.z;
        half zFace = LinearEyeDepth(tex2D(_CameraDepthTexture, ray.uv));
        half zBack = max(tex2D(_BackFaceDepthBuffer, ray.uv), zFace + 0.1h);

        if (zRay > zFace && zRay < zBack)
        {
            ray.hit = true;
        }
    }
    */
}

half ContactShadow(v2f_img IN) : SV_TARGET
{
    return 1.0h;
}

half BlurInDir(half2 uv, half2 dir)
{
    /*
    half sM = tex2D(_MainTex, uv);
    half zM = LinearEyeDepth(tex2D(_CameraDepthTexture, uv));
    half nM = mad(tex2D(_CameraGBufferTexture2, uv), 2.0h, -1.0h);

    half2 step = _MainTex_TexelSize.xy * dir;

    half sB = 0.0h;
    half sN = 0.0h;

    [unroll]
    for(uint i = 0; i < KERNEL_TAPS; i ++)
    {
        half2 offsetUv = mad(step, aTorusKernel[i].x, uv);
        //half2 offsetUv = uv + _MainTex_TexelSize.xy * dir * aTorusKernel[i].x;

        half sS = tex2D(_MainTex, offsetUv);
        
        half zS = LinearEyeDepth(tex2D(_CameraDepthTexture, offsetUv));
        half nS = mad(tex2D(_CameraGBufferTexture2, offsetUv), 2.0h, -1.0h);

        half s = exp(-abs(zS - zM) * 32.0h) * exp(-distance(nS, nM) * 32.0h);

        sB += sS * aTorusKernel[i].y * s;
        sN += aTorusKernel[i].y * s;
    }

    return sB / sN;
    */
    return 1.0h;
}

#endif