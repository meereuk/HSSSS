// Alloy Physical Shader Framework
// Copyright 2013-2016 RUST LLC.
// http://www.alloy.rustltd.com/

///////////////////////////////////////////////////////////////////////////////
/// @file Brdf.cginc
/// @brief BRDF constants and functions.
///////////////////////////////////////////////////////////////////////////////

#ifndef A_FRAMEWORK_BRDF_CGINC
#define A_FRAMEWORK_BRDF_CGINC

#include "Assets/HSSSS/Framework/Utility.cginc"

#include "UnityStandardUtils.cginc"

/// Maximum linear-space non-metal specular reflectivity.
#define A_MAX_DIELECTRIC_F0 (0.08h)

/// Minimum roughness that won't cause specular artifacts.
#define A_MIN_AREA_ROUGHNESS (0.05h)

/// Calculates the fresnel at incidence zero from a normalized specularity.
/// @param  specularity Normalized specularity [0,1].
/// @return             F0 [0,0.08].
half3 aSpecularityToF0(
    half specularity)
{
    return (specularity * A_MAX_DIELECTRIC_F0).rrr;
}

/// Calculates the specular tint from the base color. 
/// @param  color           LDR base color.
/// @param  specularTint    Weight of the specular tint [0,1].
/// @return                 Specular tint color.
half3 aSpecularTint(
    half3 color,
    half specularTint)
{
    return aLerpWhiteTo(aChromaticity(color), specularTint);
}

/// Convert linear roughness to Beckmann roughness.
/// @param  roughness   Linear roughness [0,1].
/// @return             Beckmann Roughness.
half aLinearToBeckmannRoughness(
    half roughness)
{
    // Remap roughness to prevent specular artifacts.
    roughness = lerp(A_MIN_AREA_ROUGHNESS, 1.0h, roughness);
    return roughness * roughness;
}

/// Calculates specular occlusion.
/// @param  ao      Linear ambient occlusion.
/// @param  NdotV   Normal and eye vector dot product [0,1].
/// @return         Specular occlusion.
half aSpecularOcclusion(
    half ao, 
    half NdotV) 
{	
    // Yoshiharu Gotanda's specular occlusion approximation:
    // cf http://research.tri-ace.com/Data/cedec2011_RealtimePBR_Implementation_e.pptx pg59
    half d = NdotV + ao;
    return saturate((d * d) - 1.0h + ao);
}

/// Blend weight portion of Schlick fresnel equation.
/// @param  w   Clamped dot product of two normalized vectors.
/// @return     Fresnel blend weight.
half aFresnel(
    half w) 
{
    // Sebastien Lagarde's spherical gaussian approximation of Schlick fresnel.
    // cf http://seblagarde.wordpress.com/2011/08/17/hello-world/
    return exp2((-5.55473h * w - 6.98316h) * w);
}

/// A diffuse BRDF affected by roughness.
/// @param  albedo      Diffuse albedo LDR color.
/// @param  roughness   Linear roughness [0,1].
/// @param  LdotH       Light and half-angle clamped dot product [0,1].
/// @param  NdotL       Normal and light clamped dot product [0,1].
/// @param  NdotV       Normal and view clamped dot product [0,1].
/// @return             Direct diffuse BRDF.
half3 aDiffuseBrdf(
    half3 albedo,
    half roughness,
    half LdotH,
    half NdotL,
    half NdotV)
{
    // Brent Burley diffuse BRDF.
    // cf https://disney-animation.s3.amazonaws.com/library/s2012_pbs_disney_brdf_notes_v2.pdf pg14
    half FL = aFresnel(NdotL);
    half FV = aFresnel(NdotV);
    half Fd90 = 0.5h + (2.0h * LdotH * LdotH * roughness);
    half Fd = aLerpOneTo(Fd90, FL) * aLerpOneTo(Fd90, FV);

    // Pi is cancelled by implicit punctual lighting equation.
    // cf http://seblagarde.wordpress.com/2012/01/08/pi-or-not-to-pi-in-game-lighting-equation/
    return albedo * Fd;
}

/// A specular BRDF.
/// @param  f0      Fresnel reflectance at incidence zero, LDR color.
/// @param  a       Beckmann roughness [0,1].
/// @param  LdotH   Light and half-angle clamped dot product [0,1].
/// @param  NdotH   Normal and half-angle clamped dot product [0,1].
/// @param  NdotL   Normal and light clamped dot product [0,1].
/// @param  NdotV   Normal and view clamped dot product [0,1].
/// @return         Direct specular BRDF.
half3 aSpecularBrdf(
    half3 f0, 
    half a,
    half LdotH, 
    half NdotH, 
    half NdotL, 
    half NdotV) 
{	
    // Schlick's Fresnel approximation.
    half3 f = lerp(f0, half3(1.0h, 1.0h, 1.0h), aFresnel(LdotH));

    // GGX (Trowbridge-Reitz) NDF
    // cf http://graphicrants.blogspot.com/2013/08/specular-brdf-reference.html
    half a2 = a * a;
    half denom = aLerpOneTo(a2, NdotH * NdotH);
    
    // Pi is cancelled by implicit punctual lighting equation.
    // cf http://seblagarde.wordpress.com/2012/01/08/pi-or-not-to-pi-in-game-lighting-equation/
    half d = a2 / (denom * denom);

    // John Hable's visibility function.
    // cf http://www.filmicworlds.com/2014/04/21/optimizing-ggx-shaders-with-dotlh/
    half k = a * 0.5h;
    half v = lerp(k * k, 1.0h, LdotH * LdotH);

    // Cook-Torrance microfacet model.
    // cf http://graphicrants.blogspot.com/2013/08/specular-brdf-reference.html
    return f * (d / (4.0h * v));
}

/// An environment BRDF affected by roughness.
/// @param  f0          Fresnel reflectance at incidence zero, LDR color.
/// @param  roughness   Linear roughness [0,1].
/// @param  NdotV       Normal and view clamped dot product [0,1].
/// @return             Environment BRDF.
half3 aEnvironmentBrdf(
    half3 f0,
    half roughness,
    half NdotV)
{
    // Brian Karis' modification of Dimitar Lazarov's Environment BRDF.
    // cf https://www.unrealengine.com/blog/physically-based-shading-on-mobile
    const half4 c0 = half4(-1.0h, -0.0275h, -0.572h, 0.022h);
    const half4 c1 = half4(1.0h, 0.0425h, 1.04h, -0.04h);
    half4 r = roughness * c0 + c1;
    half a004 = min(r.x * r.x, exp2(-9.28h * NdotV)) * r.x + r.y;
    half2 AB = half2(-1.04h, 1.04h) * a004 + r.zw;
    return f0 * AB.x + AB.yyy;
}

#endif // A_FRAMEWORK_BRDF_CGINC
