#ifndef A_FRAMEWORK_LIGHTING_CGINC
#define A_FRAMEWORK_LIGHTING_CGINC

// NOTE: Config comes first to override Unity settings!
#include "Assets/Alloy/Shaders/Config.cginc"
#include "Assets/HSSSS/Framework/Brdf.cginc"
#include "Assets/HSSSS/Framework/Indirect.cginc"
#include "Assets/HSSSS/Framework/Surface.cginc"
#include "Assets/HSSSS/Framework/Utility.cginc"

#include "Assets/HSSSS/Framework/Direct.cginc"

#include "HLSLSupport.cginc"
#include "UnityCG.cginc"
#include "UnityLightingCommon.cginc"
#include "UnityStandardBRDF.cginc"

#if !defined(A_REFLECTION_PROBES_OFF) && defined(UNITY_PASS_DEFERRED) && UNITY_ENABLE_REFLECTION_BUFFERS
    #define A_REFLECTION_PROBES_OFF
#endif

#define A_SKIN_BUMP_BLUR_BIAS (3.0)

half3 aStandardDirect(ADirect d, ASurface s)
{
    // Punctual light equation, with Cook-Torrance microfacet model.
    return d.color * (d.shadow.r * d.NdotL) * (
        aDiffuseBrdf(s.albedo, s.roughness, d.LdotH, d.NdotL, s.NdotV) * (1.0h - s.scatteringMask)
        + (s.specularOcclusion * d.specularIntensity
            * aSpecularBrdf(s.f0, s.beckmannRoughness, d.LdotH, d.NdotH, d.NdotL, s.NdotV)));
}

half3 aStandardIndirect(AIndirect i, ASurface s)
{
    half3 ambient = i.diffuse * s.ambientOcclusion;

    #ifdef A_REFLECTION_PROBES_OFF
    // Diffuse and fake interreflection only.
    return ambient * (s.albedo + s.f0 * (1.0h - s.specularOcclusion));
    #else
    // Full equation.
    return ambient * s.albedo
        + lerp(ambient * s.f0, i.specular * aEnvironmentBrdf(s.f0, s.roughness, s.NdotV), s.specularOcclusion);
    #endif
}

#if defined(_FACEWORKS_TYPE2)

half3 aStandardSkin
(
    ADirect d,
    ASurface s,
    sampler2D skinLut,
    sampler2D shadowLut,
    half sssBias,
    half sssScale,
    half shadowBias,
    half shadowScale
)
{
    // pre-integrated skin shading in nvidia faceworks
    float deltaNormal = length(fwidth(s.ambientNormalWorld));
    float deltaPosition = length(fwidth(s.positionWorld));

    float curvature = deltaNormal / deltaPosition * 0.01f;
    curvature = curvature * sssScale + sssBias;

    float blurredNdotL = dot(d.direction, s.ambientNormalWorld);
    float2 sssLookupUv = float2(blurredNdotL * 0.5f + 0.5f, 1.0f - curvature);

    half3 sss = tex2D(skinLut, sssLookupUv).rgb * 0.50f - 0.25f;

    float3 blurredNormalFactor = saturate(1.0f - blurredNdotL);
    blurredNormalFactor = blurredNormalFactor * blurredNormalFactor;

    float3 normalShadeG = normalize(lerp(s.normalWorld, s.ambientNormalWorld, 0.3 + 0.7 * blurredNormalFactor));
    float3 normalShadeB = normalize(lerp(s.normalWorld, s.ambientNormalWorld, blurredNormalFactor));
    float ndlShadeG = saturate(dot(d.direction, normalShadeG));
    float ndlShadeB = saturate(dot(d.direction, normalShadeB));

    float3 rgbNdotL = float3(saturate(blurredNdotL), ndlShadeG, ndlShadeB);

    // shadow penumbra scattering
    float2 shadowLookupUv = float2(d.shadow.r, saturate(1.0f - (d.NdotL * shadowScale + shadowBias)));
    half3 shadow = tex2D(shadowLut, shadowLookupUv).rgb;
    sss = saturate(sss + rgbNdotL) * s.scatteringMask * shadow;

    return d.color * s.albedo * sss;
}

#elif defined(_FACEWORKS_TYPE1)

half3 aStandardSkin
(
    ADirect d,
    ASurface s,
    sampler2D skinLut,
    half sssBias,
    half sssScale
)
{
    // pre-integrated skin shading in nvidia faceworks
    
    float deltaNormal = length(fwidth(s.ambientNormalWorld));
    float deltaPosition = length(fwidth(s.positionWorld));

    float curvature = deltaNormal / deltaPosition * 0.01f;
    curvature = curvature * sssScale + sssBias;

    float blurredNdotL = dot(d.direction, s.ambientNormalWorld);
    float2 sssLookupUv = float2(blurredNdotL * 0.5f + 0.5f, 1.0f - curvature);

    half3 sss = tex2D(skinLut, sssLookupUv).rgb * 0.50f - 0.25f;

    float3 blurredNormalFactor = saturate(1.0f - blurredNdotL);
    blurredNormalFactor = blurredNormalFactor * blurredNormalFactor;

    float3 normalShadeG = normalize(lerp(s.normalWorld, s.ambientNormalWorld, 0.3 + 0.7 * blurredNormalFactor));
    float3 normalShadeB = normalize(lerp(s.normalWorld, s.ambientNormalWorld, blurredNormalFactor));
    float ndlShadeG = saturate(dot(d.direction, normalShadeG));
    float ndlShadeB = saturate(dot(d.direction, normalShadeB));

    float3 rgbNdotL = float3(saturate(blurredNdotL), ndlShadeG, ndlShadeB);

    sss = saturate(sss + rgbNdotL) * s.scatteringMask * d.shadow.r;

    return d.color * s.albedo * sss;
}

#else

half3 aStandardSkin
(
    ADirect d,
    ASurface s,
    sampler2D skinLut,
    half sssBias,
    half sssScale
)
{
    half scattering = saturate(s.transmission * sssScale + sssBias);
    float ndlBlur = dot(d.direction, s.ambientNormalWorld) * 0.5h + 0.5h;
    float2 sssLookupUv = float2(ndlBlur, scattering * aLuminance(d.color));
    half3 sss = s.scatteringMask * d.shadow * tex2D(skinLut, sssLookupUv).rgb;

    return d.color * s.albedo * sss;
}

#endif

half3 aStandardTransmission(
    ADirect d,
    ASurface s,
    half3 transmissionColor,
    half weight,
    half distortion,
    half falloff,
    half shadowWeight)
{
    half3 transLightDir = d.direction + s.normalWorld * distortion;
    half transLight = pow(aDotClamp(s.viewDirWorld, -transLightDir), falloff);

    transLight *= weight * aLerpOneTo(d.shadow.r, shadowWeight);
    return d.color * s.albedo * transmissionColor * transLight;
}

#endif