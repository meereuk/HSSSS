#ifndef HSSSS_SSAO_CGINC
#define HSSSS_SSAO_CGINC

#include "Common.cginc"

uniform half _SSAORayLength;
uniform half _SSAODepthBias;
uniform half _SSAODepthFade;
uniform half _SSAOMixFactor;
uniform half _SSAOIndirectP;

#ifndef _SSAONumSample
#define _SSAONumSample 8
#endif

#ifndef _SSAONumStride
#define _SSAONumStride 4
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
    for (uint iter = 1; iter <= _SSAONumStride && ray.hit == false; iter ++)
    {
        ray.step = (half) iter / _SSAONumStride;

        half4 vp = vpos + vdir * ray.len * ray.step;
        half4 sp = mul(unity_CameraProjection, vp);

        ray.uv = sp.xy / sp.w * 0.5h + 0.5h;

        half zRay = -vp.z;
        half zFace = LinearEyeDepth(tex2D(_CameraDepthTexture, ray.uv));
        half zBack = max(tex2D(_BackFaceDepthBuffer, ray.uv), zFace + 0.1h);

        if (zRay > zFace && zRay < zBack)
        {
            ray.hit = true;
        }
    }
}

inline half4 IndirectOcclusion(v2f_img IN) : SV_TARGET
{
    // coordinate
    half depth;
    half4 vpos;
    half4 wpos;

    SampleCoordinates(IN, vpos, wpos, depth);

    // normal
    half3 wnrm = tex2D(_CameraGBufferTexture2, IN.uv);
    wnrm = normalize(mad(wnrm, 2.0f, -1.0f));

    // rotation matrix
    half3x3 tbn = GramSchmidtMatrix(IN.uv, wnrm);

    half4 ao = 0.0h;

    half depthBias = _SSAODepthBias * 0.01h;

    ray ray;
    ray.len = _SSAORayLength * mad(GradientNoiseAlt(mad(IN.uv.yx, 2.2f, _Time.xx)), 0.005f, 0.005f);
    ray.pos = wpos + half4(wnrm, 0.0f) * depthBias;
    ray.step = 0.0h;

    uint idx = (uint) (32.0f * GradientNoise(mad(IN.uv.yx, 2.5f, _Time.xx)));

    if (depth < _SSAODepthFade)
    {
        [unroll]
        for (uint iter = 0; iter < _SSAONumSample; iter ++)
        {
            ray.dir = half4(normalize(mul(hemiSphere[iter + idx], tbn)), 0.0h);
            ray.hit = false;
        
            RayTraceIteration(ray);
            
            ao.a += max(0.0h, ray.step);
            ao.rgb += ray.dir.rgb * max(0.0h, ray.step);
            /*
            if (!ray.hit)
            {
                ao.a += 1.0h;
                ao.rgb += ray.dir.rgb;
            }
            */
        }

        ao.rgb = normalize(ao.rgb / (ao.a + 0.001h) + wnrm.rgb * 0.001h);
        //ao.rgb = normalize(wnrm.rgb + ao.rgb);
        //ao.rgb = saturate(mad(ao.rgb, 0.5h, 0.5h));
        //ao.rgb = ao.a > 0.001h ? mad(normalize(ao.rgb), 0.5h, 0.5h) : mad(wnrm, 0.5h, 0.5h);
        ao.a /= _SSAONumSample;
    }

    else
    {
        ao.rgb = mad(wnrm, 0.5h, 0.5h);
        ao.a = 1.0h;
    }

    if (_SSAOMixFactor > 0.0h)
    {
        half2 uvOld = GetAccumulationUv(wpos);
        half4 aoOld = tex2D(_SSGITemporalAOBuffer, uvOld);
        aoOld.rgb = mad(aoOld.rgb, 2.0h, -1.0h);

        ao = lerp(ao, aoOld, min(_SSAOMixFactor, 0.99h));
        ao.rgb = normalize(ao.xyz);
    }

    ao.rgb = mad(ao.rgb, 0.5h, 0.5h);
    return saturate(ao);
}

inline half4 TemporalFiltering(v2f_img IN) : SV_TARGET
{
    half depth;
    half4 vpos;
    half4 wpos;

    SampleCoordinates(IN, vpos, wpos, depth);

    half2 uvOld = GetAccumulationUv(wpos);

    half4 newAO = tex2D(_MainTex, IN.uv);
    half4 oldAO = tex2D(_SSGITemporalAOBuffer, uvOld);

    newAO.xyz = mad(newAO.xyz, 2.0h, -1.0h);
    oldAO.xyz = mad(oldAO.xyz, 2.0h, -1.0h);

    half4 ao = lerp(newAO, oldAO, min(_SSAOMixFactor, 0.99h));
    ao.xyz = mad(normalize(ao.xyz), 0.5h, 0.5h);

    return ao;
}

inline half4 ApplyOcclusionToGBuffer0(v2f_img IN) : SV_TARGET
{
    /*
    half4 color = tex2D(_CameraGBufferTexture0, IN.uv);
    half ao = tex2D(_SSGITemporalAOBuffer, IN.uv);
    ao = saturate(pow(ao, _SSAOIndirectP));
    */

    half4 bnrm = tex2D(_SSGITemporalAOBuffer, IN.uv);
    half4 wnrm = tex2D(_CameraGBufferTexture2, IN.uv); 
    half4 color = tex2D(_CameraGBufferTexture0, IN.uv);

    bnrm.rgb = normalize(mad(bnrm.rgb, 2.0h, -1.0h));
    wnrm.rgb = normalize(mad(wnrm.rgb, 2.0h, -1.0h));

    half ao = bnrm.a * saturate(dot(bnrm.rgb, wnrm.rgb));
    ao = saturate(pow(ao, _SSAOIndirectP));

    return half4(color.rgb, min(color.a, ao));
}

inline half4 ApplyOcclusionToGBuffer3(v2f_img IN) : SV_TARGET
{
    /*
    half4 color = tex2D(_CameraGBufferTexture3, IN.uv);
    half ao = tex2D(_SSGITemporalAOBuffer, IN.uv);
    ao = saturate(pow(ao, _SSAOIndirectP));
    */

    half4 bnrm = tex2D(_SSGITemporalAOBuffer, IN.uv);
    half4 wnrm = tex2D(_CameraGBufferTexture2, IN.uv); 
    half4 color = tex2D(_CameraGBufferTexture3, IN.uv);

    bnrm.rgb = normalize(mad(bnrm.rgb, 2.0h, -1.0h));
    wnrm.rgb = normalize(mad(wnrm.rgb, 2.0h, -1.0h));

    half ao = bnrm.a * saturate(dot(bnrm.rgb, wnrm.rgb));
    ao = saturate(pow(ao, _SSAOIndirectP));

    return half4(color.rgb * ao, color.a);
}

#endif