#ifndef A_FRAMEWORK_DEFERRED_CGINC
#define A_FRAMEWORK_DEFERRED_CGINC

#include "Assets/HSSSS/Config.cginc"
#include "Assets/HSSSS/Framework/Surface.cginc"
#include "Assets/HSSSS/Framework/Utility.cginc"

#include "Assets/HSSSS/Framework/Direct.cginc"
#include "Assets/HSSSS/Framework/Lighting.cginc"

#include "HLSLSupport.cginc"
#include "UnityCG.cginc"
#include "UnityPBSLighting.cginc"
#include "UnityStandardBRDF.cginc"
#include "UnityStandardUtils.cginc"

#if defined(_PCF_TAPS_8) || defined(_PCF_TAPS_16) || defined(_PCF_TAPS_32) || defined(_PCF_TAPS_64)
    #include "Assets/HSSSS/Unity/HSSSSDeferredLibrary.cginc"
#else
    #include "UnityDeferredLibrary.cginc"
#endif

#if defined(_RT_SHADOW_LQ) || defined(_RT_SHADOW_MQ) || defined(_RT_SHADOW_HQ)
    #define _RT_SHADOW
#endif

#if defined(_RT_SHADOW)
#include "Assets/HSSSS/Unity/ScreenSpaceShadows.cginc"
#endif

sampler2D _CameraGBufferTexture0;
sampler2D _CameraGBufferTexture1;
sampler2D _CameraGBufferTexture2;

ASurface aDeferredSurface(inout unity_v2f_deferred i)
{
    i.ray = i.ray * (_ProjectionParams.z / i.ray.z);

    float2 uv = i.uv.xy / i.uv.w;
    ASurface s = aCreateSurface();

    float depth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));
    float4 vpos = float4(i.ray * depth,1);
    float3 positionWorld = mul(_CameraToWorld, vpos).xyz;

    s.viewDepth = vpos.z;

    half4 gbuffer0 = tex2D(_CameraGBufferTexture0, uv);
    half4 gbuffer1 = tex2D(_CameraGBufferTexture1, uv);
    half4 gbuffer2 = tex2D(_CameraGBufferTexture2, uv);

    s.screenUv = uv;
    s.positionWorld = positionWorld;

    s.albedo = gbuffer0.rgb;
    s.ambientOcclusion = gbuffer0.a;

    s.f0 = gbuffer1.rgb;
    s.roughness = 1.0h - gbuffer1.a;

    s.normalWorld = normalize(gbuffer2.rgb * 2.0h - 1.0h);
    s.scatteringMask = 1.0h - gbuffer2.a;

    s.viewDirWorld = normalize(UnityWorldSpaceViewDir(positionWorld));
    s.beckmannRoughness = aLinearToBeckmannRoughness(s.roughness);

    aUpdateViewData(s);
    aUnpackGbuffer(s);
    return s;
}

ADirect aDeferredDirect(ASurface s)
{
    ADirect d = aCreateDirect();
    float fadeDist = UnityDeferredComputeFadeDistance(s.positionWorld, s.viewDepth);
    float3 lightVector = 0.0f;
    half3 lightAxis = 0.0h;
    half range = 1.0h;

    d.color = _LightColor.rgb;

    // directional light
    #if defined(DIRECTIONAL) || defined(DIRECTIONAL_COOKIE)
        #if defined(_PCF_TAPS_8) || defined(_PCF_TAPS_16) || defined(_PCF_TAPS_32) || defined(_PCF_TAPS_64)
            #if defined(_DIR_PCF_ON)
                d.shadow = CustomDirectionalShadow(s.positionWorld, s.viewDepth, fadeDist, s.screenUv, saturate(dot(s.normalWorld, d.direction)));
            #else
                d.shadow = UnityDeferredComputeShadow(s.positionWorld, fadeDist, s.screenUv, saturate(dot(s.normalWorld, d.direction)));
            #endif
        #else
            d.shadow = UnityDeferredComputeShadow(s.positionWorld, fadeDist, s.screenUv);
        #endif

        #if defined(_RT_SHADOW)
        SampleScreenSpaceShadow(s.positionWorld, s.screenUv, -_LightDir.xyz, d.shadow);
        #endif

        lightVector = -_LightDir.xyz;
        
        #if !defined(ALLOY_SUPPORT_REDLIGHTS) && defined(DIRECTIONAL_COOKIE)
            half4 cookie = tex2Dbias(_LightTexture0, float4(mul(_LightMatrix0, half4(s.positionWorld, 1)).xy, 0, -8));
            
            d.color *= A_LIGHT_COOKIE(cookie);
        #endif

    // spot & point lights
    #elif defined(SPOT)|| defined(POINT) || defined(POINT_COOKIE)
        lightVector = _LightPos.xyz - s.positionWorld;
        lightAxis = normalize(_LightMatrix0[1].xyz);
        range = rsqrt(_LightPos.w); // _LightPos.w = 1/r*r

        // spot light
        #if defined (SPOT)
            float4 uvCookie = mul(_LightMatrix0, float4(s.positionWorld, 1.0f));
            // negative bias because http://aras-p.info/blog/2010/01/07/screenspace-vs-mip-mapping/
            half4 cookie = tex2Dbias(_LightTexture0, float4(uvCookie.xy / uvCookie.w, 0, -8));
        
            cookie.a *= (uvCookie.w < 0.0f);
            d.color *= A_LIGHT_COOKIE(cookie);
            #if defined(_PCF_TAPS_8) || defined(_PCF_TAPS_16) || defined(_PCF_TAPS_32) || defined(_PCF_TAPS_64)
                d.shadow = UnityDeferredComputeShadow(s.positionWorld, fadeDist, s.screenUv, saturate(dot(s.normalWorld, d.direction)));
            #else
                d.shadow = UnityDeferredComputeShadow(s.positionWorld, fadeDist, s.screenUv);
            #endif

            #if defined(_RT_SHADOW)
            SampleScreenSpaceShadow(s.positionWorld, s.screenUv, lightVector, d.shadow);
            #endif
            
            #if A_USE_UNITY_ATTENUATION
                float att = dot(lightVector, lightVector) * _LightPos.w;
                d.color *= tex2D(_LightTextureB0, att.rr).UNITY_ATTEN_CHANNEL;
            #endif	
        #endif

        // point light
        #if defined (POINT) || defined (POINT_COOKIE)
            #if defined(_PCF_TAPS_8) || defined(_PCF_TAPS_16) || defined(_PCF_TAPS_32) || defined(_PCF_TAPS_64)
                d.shadow = UnityDeferredComputeShadow(-lightVector, fadeDist, s.screenUv, d.NdotL);
            #else
                d.shadow = UnityDeferredComputeShadow(-lightVector, fadeDist, s.screenUv);
            #endif

            #if defined(_RT_SHADOW)
            SampleScreenSpaceShadow(s.positionWorld, s.screenUv, lightVector, d.shadow);
            #endif
                
            #if defined (POINT_COOKIE)
                half4 cookie = texCUBEbias(_LightTexture0, float4(mul(_LightMatrix0, half4(s.positionWorld, 1)).xyz, -8));
                d.color *= A_LIGHT_COOKIE(cookie);
            #endif

            #if A_USE_UNITY_ATTENUATION
                float att = dot(lightVector, lightVector) * _LightPos.w;
                d.color *= tex2D(_LightTextureB0, att.rr).UNITY_ATTEN_CHANNEL;
            #endif
        #endif
    #endif

    #if !(defined(ALLOY_SUPPORT_REDLIGHTS) && defined(DIRECTIONAL_COOKIE))
        aAreaLight(d, s, _LightColor, lightVector, lightAxis, range);
    #else
        d.direction = lightVector;
        d.color *= redLightFunctionLegacy(_LightTexture0, s.positionWorld, s.normalWorld, s.viewDirWorld, d.direction);
        aDirectionalLight(d, s, d.direction);
    #endif

    return d;
}

#endif