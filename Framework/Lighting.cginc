#ifndef A_FRAMEWORK_LIGHTING_CGINC
#define A_FRAMEWORK_LIGHTING_CGINC

// NOTE: Config comes first to override Unity settings!
#include "Assets/HSSSS/Config.cginc"
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

inline void aStandardDirect(ADirect d, ASurface s, out half3 diffuse, out half3 specular)
{
    half3 diffuseLight = d.color * d.shadow.r;
    half3 specularLight = diffuseLight * s.specularOcclusion * d.specularIntensity * d.NdotL;

    half3 sheen = DCharlie(s.beckmannRoughness, d.NdotH) * VNeubelt(s.NdotV, d.NdotL) * s.f0;

    specular = FSchlick(s.f0, d.LdotH);
    diffuse = d.NdotL;

    sheen *= specularLight;
    specular *= specularLight;
    diffuse *= diffuseLight;

    half3 sssColor = saturate(s.albedo * s.albedo + 0.1h);
    sssColor = 0.1h * sssColor / aLuminance(sssColor);

    // skin
    if (s.scatteringMask == SHADING_MODEL_SKIN)
    {
        diffuse *= aDiffuseBrdf(s.roughness, d.LdotH, d.NdotL, s.NdotV);
        specular *= DGGX(s.beckmannRoughness, d.NdotH);
        specular *= VSmith(s.beckmannRoughness, s.NdotV, d.NdotL);
        specular += sheen;

        return;
    }

    // sheen
    else if (s.scatteringMask == SHADING_MODEL_SHEEN)
    {
        diffuse *= aSubSurfaceBrdf(s.roughness, d.LdotH, d.NdotL, s.NdotV);
        specular = sheen;

        return;
    }

    // anisotropic
    else if (s.scatteringMask == SHADING_MODEL_ANISOTROPIC)
    {
        half3 halfvector = normalize(d.direction + s.viewDirWorld);

        half frac = s.normalWorld.y * s.normalWorld.y;

        half3 bitangent = normalize(lerp(half3(0.0h, 1.0h, 0.0h), half3(1.0h, 0.0h, 0.0h), frac * frac));
        bitangent = normalize(bitangent - s.normalWorld * dot(s.normalWorld, bitangent));
        
        half3 tangent = normalize(cross(s.normalWorld, bitangent));

        half TdotH = dot(tangent, halfvector);
        half BdotH = dot(bitangent, halfvector);

        half TdotV = dot(tangent, s.viewDirWorld);
        half BdotV = dot(bitangent, s.viewDirWorld);

        half TdotL = dot(tangent, d.direction);
        half BdotL = dot(bitangent, d.direction);

        half anisotropy = clamp(mad(s.transmission, 2.0h, -1.0h), -1.0h, 1.0h);

        half at = s.beckmannRoughness * clamp(1.0h + anisotropy, 0.001f, 1.999f);
        half ab = s.beckmannRoughness * clamp(1.0h - anisotropy, 0.001f, 1.999f);

        diffuse *= aSubSurfaceBrdf(s.roughness, d.LdotH, d.NdotL, s.NdotV);
        specular *= DGGXAniso(at, ab, TdotH, BdotH, d.NdotH);
        specular *= VSmithAniso(at, ab, TdotV, BdotV, TdotL, BdotL, s.NdotV, d.NdotL);

        return;
    }

    // standard
    else
    {
        diffuse *= aDiffuseBrdf(s.roughness, d.LdotH, d.NdotL, s.NdotV);
        specular *= DGGX(s.beckmannRoughness, d.NdotH);
        specular *= VSmith(s.beckmannRoughness, s.NdotV, d.NdotL);

        return;
    }
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

// pre-integrated brdf in nvidia faceworks
inline half3 aStandardSkin
(
    ADirect d, ASurface s, sampler2D skinLut,
    #if defined(_FACEWORKS_TYPE2)
        sampler2D shadowLut, half sssBias, half sssScale, half shadowBias, half shadowScale
    #else
        half sssBias, half sssScale
    #endif
)
{
    float deltaNormal = length(fwidth(s.ambientNormalWorld));
    float deltaPosition = length(fwidth(s.positionWorld));

    float curvature = deltaNormal / deltaPosition * 0.01f;
    curvature = curvature * sssScale + sssBias;

    float blurredNdotL = dot(d.direction, s.ambientNormalWorld);

    // nvidia faceworks
    #if defined(_FACEWORKS_TYPE1) || defined(_FACEWORKS_TYPE2)
        float2 sssLookupUv = float2(blurredNdotL * 0.5f + 0.5f, 1.0f - curvature);
        half3 sss = tex2D(skinLut, sssLookupUv).rgb * 0.50f - 0.25f;

        float3 blurredNormalFactor = saturate(1.0f - blurredNdotL);
        blurredNormalFactor = blurredNormalFactor * blurredNormalFactor;

        float3 normalShadeG = normalize(lerp(s.normalWorld, s.ambientNormalWorld, 0.3 + 0.7 * blurredNormalFactor));
        float3 normalShadeB = normalize(lerp(s.normalWorld, s.ambientNormalWorld, blurredNormalFactor));
        float ndlShadeG = saturate(dot(d.direction, normalShadeG));
        float ndlShadeB = saturate(dot(d.direction, normalShadeB));

        float3 rgbNdotL = float3(saturate(blurredNdotL), ndlShadeG, ndlShadeB);

        #if defined(_FACEWORKS_TYPE1)
            sss = saturate(sss + rgbNdotL) * s.scatteringMask * d.shadow.r;
        #elif defined(_FACEWORKS_TYPE2)
            float2 shadowLookupUv = float2(d.shadow.r, saturate(1.0f - (d.NdotL * shadowScale + shadowBias)));
            half3 shadow = tex2D(shadowLut, shadowLookupUv).rgb;
            sss = saturate(sss + rgbNdotL) * s.scatteringMask * shadow;
        #endif
    //eric penner
    #else
        float2 sssLookupUv = float2(blurredNdotL * 0.5f + 0.5f, curvature * aLuminance(d.color));
        half3 sss = tex2D(skinLut, sssLookupUv).rgb * s.scatteringMask * d.shadow.r;
    #endif

    return d.color * sss;
}

// skin transmittance
inline half3 aStandardTransmission
(
    ADirect d, ASurface s,
    #if defined (_BAKED_THICKNESS)
        half3 transmissionColor, half weight, half distortion, half falloff, half shadowWeight
    #else
        sampler2D lut, half weight, half falloff, half bias
    #endif
)
{
    #if defined(_BAKED_THICKNESS)
        half3 transLightDir = d.direction + s.normalWorld * distortion;
        half transLight = pow(aDotClamp(s.viewDirWorld, -transLightDir), falloff);

        transLight *= weight * aLerpOneTo(d.shadow.r, shadowWeight);
        return d.color * transmissionColor * transLight;
    #elif !defined(SHADOWS_OFF)
        half thickness = 2.0f * falloff * max(bias, d.shadow.g);
        half3 attenuation = tex2D(lut, float2(thickness * thickness, 0.5f));
        attenuation = 0.25h * attenuation * weight * saturate(0.3h - dot(s.ambientNormalWorld, d.direction));
        return d.color * attenuation;
    #else
        return 0.0h;
    #endif
}

// thin layer transmittance for clothes
inline half3 aThinTransmission(ADirect d, ASurface s, half weight)
{
    half attenuation = 0.1f * weight * saturate(0.3f - dot(s.ambientNormalWorld, d.direction));
    return d.color * attenuation * d.shadow.r;
}

#endif