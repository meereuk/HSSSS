// Alloy Physical Shader Framework
// Copyright 2013-2016 RUST LLC.
// http://www.alloy.rustltd.com/

/////////////////////////////////////////////////////////////////////////////////
/// @file Direct.cginc
/// @brief ADirect structure, and related methods.
/////////////////////////////////////////////////////////////////////////////////

#ifndef A_FRAMEWORK_DIRECT_CGINC
#define A_FRAMEWORK_DIRECT_CGINC

// NOTE: Config comes first to override Unity settings!
#include "Assets/HSSSS/Framework/Brdf.cginc"
#include "Assets/HSSSS/Framework/Surface.cginc"
#include "Assets/HSSSS/Framework/Utility.cginc"

#include "HLSLSupport.cginc"
#include "UnityCG.cginc"
#include "UnityLightingCommon.cginc"
#include "UnityStandardBRDF.cginc"

// Handles case in injection code where the base pass directional is a scalar.
#if defined(UNITY_PASS_FORWARDBASE) || A_USE_UNITY_LIGHT_COOKIES
    #define A_LIGHT_COOKIE(cookie, atten) (cookie.a)
#else
    #define A_LIGHT_COOKIE(cookie) (cookie.rgb * cookie.a)
#endif

/// Collection of direct illumination data.
struct ADirect {
    /////////////////////////////////////////////////////////////////////////////
    // Material lighting.
    /////////////////////////////////////////////////////////////////////////////

    /// Light color, attenuation, and cookies.
    /// Expects linear-space HDR color values.
    half3 color;
        
    /// Shadowing.
    /// Expects values in the range [0,1].
    half2 shadow;
    
    /// Specular highlight intensity.
    /// Expects values in the range [0,n].
    half specularIntensity;

    /// Light direction in world-space.
    /// Expects normalized vectors in the range [-1,1].
    half3 direction;
    
    /// Direction halfway between the light and view vectors in world space.
    /// Expects normalized vectors in the range [-1,1].
    half3 halfAngleWorld;

    /// Clamped L.H.
    /// Expects values in the range [0,1].
    half LdotH;

    /// Clamped N.H.
    /// Expects values in the range [0,1].
    half NdotH;

    /// Clamped N.L.
    /// Expects values in the range [0,1].
    half NdotL;

    /// Unclamped N.L.
    /// Expects values in the range [0,1].
    half NdotLm;


    /////////////////////////////////////////////////////////////////////////////
    // Internal.
    /////////////////////////////////////////////////////////////////////////////

    /// Diffuse area light vector.
    /// Expects a non-normalized vector.
    float3 Ldiff;

    /// Specular area light vector.
    /// Expects a non-normalized vector.
    float3 Lspec;

    /// One over the distance to the center of the light volume.
    /// Expects values in the range [0,n).
    half centerDistInverse;
};

/// Constructor. 
/// @return Structure initialized with sane default values.
ADirect aCreateDirect() 
{
    ADirect d;

    UNITY_INITIALIZE_OUTPUT(ADirect, d);
    d.color = 0.0h;
    d.shadow = 1.0h;
    d.specularIntensity = 1.0h;
    d.direction = half3(0.0h, 1.0h, 0.0h);
        
    return d;
}

/// Light range limit falloff.
/// @param[in,out]  d                   Direct light description.
/// @param[in]      centerDistInverse   One over distance to the range center.
/// @param[in]      range               Light volume radius.
void aSetLightRangeLimit(
    inout ADirect d,
    half centerDistInverse,
    half range) 
{
#if !A_USE_UNITY_ATTENUATION
    // Light Range Limit Falloff.
    // cf http://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf p12-13
    half ratio = 1.0h / (range * centerDistInverse);
    half ratio2 = ratio * ratio;
    half num = saturate(1.0h - (ratio2 * ratio2));

    d.color *= num * num;
#endif
}

/// Populates light with brdf dot products, except N.L.
/// @param[in,out]  d Direct light description.
/// @param[in]      s Material surface data.
void aUpdateLightingInputs(
    inout ADirect d,
    ASurface s)
{
    d.halfAngleWorld = normalize(d.direction + s.viewDirWorld);
    d.LdotH = aDotClamp(d.direction, d.halfAngleWorld);
    d.NdotH = aDotClamp(s.normalWorld, d.halfAngleWorld);
}

/// Populates specular lighting data for an area light.
/// @param[in,out]  d       Direct light description.
/// @param[in]      s       Material surface data.
/// @param[in]      radius  Area light radius.
void aSetAreaSpecularInputs(
    inout ADirect d,
    ASurface s,
    half radius)
{
    // Representative Point Area Lights.
    // cf http://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf p14-16
#ifdef A_AREA_SPECULAR_OFF
    d.direction = d.Ldiff;
#else
    float3 R = s.reflectionVectorWorld;
    float3 centerToRay = dot(d.Lspec, R) * R - d.Lspec;
    float3 closestPoint = d.Lspec + centerToRay * saturate(radius * rsqrt(dot(centerToRay, centerToRay)));
    half LspecLengthInverse = rsqrt(dot(closestPoint, closestPoint));
    half a = s.beckmannRoughness;
    half normalizationFactor = a / saturate(a + (radius * 0.5h * LspecLengthInverse));

    d.direction = closestPoint * LspecLengthInverse;
    d.specularIntensity *= normalizationFactor * normalizationFactor;
#endif

    aUpdateLightingInputs(d, s);
}

/// Populates material lighting data for an area light.
/// @param[in,out]  d       Direct light description.
/// @param[in]      s       Material surface data.
/// @param[in]      radius  Area light radius.
/// @return                 One over area diffuse light vector length.
half aSetAreaLightingInputs(
    inout ADirect d,
    ASurface s,
    half radius)
{
    // Specular.
    aSetAreaSpecularInputs(d, s, radius);

    // Diffuse.
    // Set diffuse light direction last to fix transmission & hair.
    half LdiffLengthSquared = dot(d.Ldiff, d.Ldiff);
    half LdiffLengthInverse = rsqrt(LdiffLengthSquared);

    d.direction = d.Ldiff * LdiffLengthInverse;
    d.NdotLm = dot(s.normalWorld, d.direction);
    d.NdotL = saturate(d.NdotLm);

#if !A_USE_UNITY_ATTENUATION
    d.color /= (LdiffLengthSquared + 1.0h); // Attenuation.
#endif

    return LdiffLengthInverse;
}

/// Populates data for a directional light.
/// @param[in,out]  d           Direct light description.
/// @param[in]      s           Material surface data.
/// @param[in]      direction   Light normalized direction.
void aDirectionalLight(
    inout ADirect d,
    ASurface s,
    half3 direction)
{
    d.direction = direction;
    d.NdotLm = dot(s.normalWorld, d.direction);
    d.NdotL = saturate(d.NdotLm);
    aUpdateLightingInputs(d, s);
}

/// Populates data for a directional light.
/// @param[in,out]  d           Direct light description.
/// @param[in]      s           Material surface data.
/// @param[in]      direction   Light normalized direction.
/// @param[in]      radius      Disc light radius.
void aDirectionalDiscLight(
    inout ADirect d,
    ASurface s,
    half3 direction,
    half radius)
{
    d.Ldiff = direction;
    d.Lspec = direction;

    // Specular.
    aSetAreaSpecularInputs(d, s, radius);

    // Diffuse.
    // Set diffuse light direction last to fix transmission & hair.
    d.direction = d.Ldiff;
    d.NdotLm = dot(s.normalWorld, d.direction);
    d.NdotL = saturate(d.NdotLm);
}

/// Populates data for a sphere area light.
/// @param[in,out]  d       Direct light description.
/// @param[in]      s       Material surface data.
/// @param[in]      L       Vector to light center.
/// @param[in]      radius  Sphere light radius.
void aSphereLight(
    inout ADirect d,
    ASurface s,
    float3 L,
    half radius)
{
    // Sphere Area Light.
    // cf http://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf p15-16
    d.Ldiff = L;
    d.Lspec = L;
    d.centerDistInverse = aSetAreaLightingInputs(d, s, radius);
}

/// Populates data for a sphere area light.
/// @param[in,out]  d           Direct light description.
/// @param[in]      s           Material surface data.
/// @param[in]      L           Vector to light center.
/// @param[in]      axis        Tube light normalized axis direction.
/// @param[in]      radius      Tube light radius.
/// @param[in]      halfLength  Half the length of the tube light.
void aTubeLight(
    inout ADirect d,
    ASurface s,
    float3 L,
    half3 axis,
    half radius,
    half halfLength)
{
    // Tube Area Light.
    // cf http://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf p16-18
    float3 R = s.reflectionVectorWorld;
    float3 tubeLightDir = axis * halfLength;
    float3 L0 = L + tubeLightDir;
    float3 L1 = L - tubeLightDir;
    float3 Ld = tubeLightDir * -2.0f;
    float RdotL0 = dot(R, L0);
    float RdotLd = dot(R, Ld);
    float L0dotLd = dot(L0, Ld);
    float t = (RdotL0 * RdotLd - L0dotLd) / (dot(Ld, Ld) - RdotLd * RdotLd);

    // Modified diffuse term for true tube diffuse lighting.
    d.Ldiff = L - clamp(dot(L, axis), -halfLength, halfLength) * axis;
    d.Lspec = L0 + Ld * saturate(t);
    d.centerDistInverse = rsqrt(dot(L, L));

    // Attentuation normalization.
    d.color /= 1.0h + (0.25h * halfLength * aSetAreaLightingInputs(d, s, radius));
}

/// Populates data for an area light.
/// @param[in,out]  d       Direct light description.
/// @param[in]      s       Material surface data.
/// @param[in]      color   Light color, size weight in alpha. +/- sign.
/// @param[in]      L       Vector to light center.
/// @param[in]      axis    Tube light normalized axis direction.
/// @param[in]      range   Light bounding volume range.
void aAreaLight(
    inout ADirect d,
    ASurface s,
    half4 color,
    float3 L,
    half3 axis,
    half range)
{
    // Packed float light configuration.
    // +/- llll.rrrr: l=length, r=radius, and sign as specular toggle.
    // Radius externally clamped to .999 max to simplify math.
    half lightParams = abs(color.a);
    /*
    #if defined(DIRECTIONAL)
        half lightParams = _DirLightPenumbra.y * 0.01h;
    #elif defined(SPOT)
        half lightParams = _SpotLightPenumbra.y * 0.01h;
    #elif defined(POINT)
        half lightParams = _PointLightPenumbra.y * 0.01h;
    #else
        half lightParams = abs(color.a);
    #endif
    */

    // Specular highlight toggle.
    d.specularIntensity = color.a > 0.0h ? 1.0h : 0.0h;

    #if defined(USING_DIRECTIONAL_LIGHT) || defined(DIRECTIONAL) || defined(DIRECTIONAL_COOKIE)
        // 0.1 needed to make material inspector look okay.
        aDirectionalDiscLight(d, s, L, lightParams * 0.01h);
    #else
        #if !defined(SPOT) && A_USE_TUBE_LIGHTS
            // Enable when length is non-zero, and specular is enabled.
            if (color.a >= 1)
            {
                half radius = frac(lightParams) * range;
                half halfLength = floor(lightParams) * 0.001f * range;

                aTubeLight(d, s, L, axis, radius, halfLength);
            }

            else
        #endif
        {
            aSphereLight(d, s, L, lightParams * range * 0.001h);
        }

        aSetLightRangeLimit(d, d.centerDistInverse, range);
    #endif
}

#endif // A_FRAMEWORK_DIRECT_CGINC
