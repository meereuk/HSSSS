#ifndef A_FRAMEWORK_UNITY_CGINC
#define A_FRAMEWORK_UNITY_CGINC

#include "Assets/HSSSS/Framework/Direct.cginc"
#include "Assets/HSSSS/Framework/Lighting.cginc"
#include "Assets/HSSSS/Framework/Surface.cginc"
#include "Assets/HSSSS/Framework/Utility.cginc"

#include "AutoLight.cginc"
#include "UnityCG.cginc"
#include "UnityLightingCommon.cginc"

/// Calculates direct lighting from a UnityLight object.
/// @param  light   UnityLight populated with data.
/// @param  s       Material surface data.
/// @return         Direct illumination.
half3 aUnityLightDirect(
    UnityLight light,
    ASurface s)
{	
    ADirect d = aCreateDirect();
    d.color = light.color;
    d.direction = light.dir;
    d.NdotL = light.ndotl;
    d.NdotLm = dot(s.normalWorld, d.direction);
    aUpdateLightingInputs(d, s);

    return aDirect(d, s);
}

/// Calculates global illumination from UnityGI data.
/// @param  gi      UnityGI populated with data.
/// @param  s       Material surface data.
/// @return         Indirect illumination.
half3 aGlobalIllumination(
    UnityGI gi,
    ASurface s)
{
    half3 illum = aIndirect(gi.indirect, s);
    
#ifdef DIRLIGHTMAP_SEPARATE
    #ifdef LIGHTMAP_ON
        // Static Direct
        illum += aUnityLightDirect(gi.light, s);
    #endif

    s.albedo *= s.ambientOcclusion;
    
    #ifdef LIGHTMAP_ON
        // Static Indirect
        illum += aUnityLightDirect(gi.light2, s);
    #endif
    #ifdef DYNAMICLIGHTMAP_ON
        // Dynamic Indirect
        illum += aUnityLightDirect(gi.light3, s);
    #endif
#endif
    
    return illum;
}

/// Calculates forward direct illumination.
/// @param  positionWorld   Position in world-space.
/// @return                 XYZ: Vector to light center, W: Light volume range.
float4 aLightVectorRange(
    float4 positionWorld)
{
    float4 result = UnityWorldSpaceLightDir(positionWorld.xyz).xyzz;

#if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
    // Trick to obtain light range for point lights from projected coordinates.
    // cf http://forum.unity3d.com/threads/get-the-range-of-a-point-light-in-forward-add-mode.213430/#post-1433291
    unityShadowCoord3 lightCoord = mul(_LightMatrix0, positionWorld).xyz;
    result.w = length(result.xyz) * rsqrt(dot(lightCoord, lightCoord));
#endif

    return result;
}

/// Calculates forward direct illumination.
/// @param  s       Material surface data.
/// @param  L       Vector to light center.
/// @param  range   Light bounding volume range.
/// @param  shadow  Shadow attenuation.
/// @return         Direct illumination.
half3 aForwardDirect(
    ASurface s,
    float3 L,
    half range, 
    half shadow)
{
    ADirect d = aCreateDirect();
    half3 lightAxis = 0.0h;

    d.color = _LightColor0.rgb;
    d.shadow = shadow;
        
#ifdef USING_DIRECTIONAL_LIGHT
    #if !defined(ALLOY_SUPPORT_REDLIGHTS) && defined(DIRECTIONAL_COOKIE)
        unityShadowCoord2 lightCoord = mul(_LightMatrix0, unityShadowCoord4(s.positionWorld, 1)).xy;
        half4 cookie = tex2D(_LightTexture0, lightCoord);

        d.color *= A_LIGHT_COOKIE(cookie);
    #endif
#elif defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
    lightAxis = normalize(_LightMatrix0[1].xyz);

    #if defined(POINT)
        #if A_USE_UNITY_ATTENUATION
            unityShadowCoord3 lightCoord = mul(_LightMatrix0, unityShadowCoord4(s.positionWorld, 1)).xyz;
            d.color *= tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
        #endif
    #elif defined(POINT_COOKIE)
        unityShadowCoord3 lightCoord = mul(_LightMatrix0, unityShadowCoord4(s.positionWorld, 1)).xyz;
        half4 cookie = texCUBE(_LightTexture0, lightCoord);
        
        d.color *= A_LIGHT_COOKIE(cookie);
            
        #if A_USE_UNITY_ATTENUATION
            d.color *= tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
        #endif
    #endif

    #ifdef SPOT
        unityShadowCoord4 lightCoord = mul(_LightMatrix0, unityShadowCoord4(s.positionWorld, 1));
        half4 cookie = tex2D(_LightTexture0, lightCoord.xy / lightCoord.w + 0.5);
        
        cookie.a *= (lightCoord.z > 0);
        d.color *= A_LIGHT_COOKIE(cookie);

        #if A_USE_UNITY_ATTENUATION
            d.color *= UnitySpotAttenuate(lightCoord.xyz);
        #endif
    #endif
#endif

#if !(defined(ALLOY_SUPPORT_REDLIGHTS) && defined(DIRECTIONAL_COOKIE))
    aAreaLight(d, s, _LightColor0, L, lightAxis, range);
#else
    d.direction = L;
    d.color *= redLightCalculateForward(_LightTexture0, s.positionWorld, s.normalWorld, s.viewDirWorld, d.direction);
    aDirectionalLight(d, s, d.direction);
#endif

    return aDirect(d, s);
}

/// Populates the G-buffer with Unity-compatible material data.
/// @param[in]  s                   Material surface data.
/// @param[in]  gi                  Unity GI descriptor.
/// @param[out] outDiffuseOcclusion RGB: albedo, A: specular occlusion.
/// @param[out] outSpecSmoothness   RGB: f0, A: 1-roughness.
/// @param[out] outNormal           RGB: packed normal, A: 1-scattering mask.
/// @return                         RGB: emission, A: 1-transmission.
half4 aGbuffer(
    ASurface s,
    UnityGI gi,
    out half4 outDiffuseOcclusion,
    out half4 outSpecSmoothness,
    out half4 outNormal)
{
#ifndef UNITY_PASS_DEFERRED
    return 0.0h;
#else
    half4 emission;

    aPackGbuffer(s, outDiffuseOcclusion, outSpecSmoothness, outNormal, emission);

    #ifndef A_LIGHTING_OFF
        emission.rgb += aGlobalIllumination(gi, s);
    #endif
    return aHdrClamp(emission);
#endif
}

#endif // A_FRAMEWORK_UNITY_CGINC
