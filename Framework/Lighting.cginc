#ifndef A_FRAMEWORK_LIGHTING_CGINC
#define A_FRAMEWORK_LIGHTING_CGINC

// NOTE: Config comes first to override Unity settings!
#include "Assets/HSSSS/Config.cginc"
#include "Assets/HSSSS/Framework/Brdf.cginc"
#include "Assets/HSSSS/Framework/Indirect.cginc"
#include "Assets/HSSSS/Framework/Surface.cginc"
#include "Assets/HSSSS/Framework/Utility.cginc"
#include "Assets/HSSSS/Framework/Direct.cginc"
#include "Assets/HSSSS/Framework/AreaLight.cginc"

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
    half3 direct = d.color * d.shadow.r * d.NdotL;

    // specular brdf
    specular = direct * s.specularOcclusion * d.specularIntensity * aSpecularBrdf(s.f0, s.beckmannRoughness, d.LdotH, d.NdotH, d.NdotL, s.NdotV);

    // disney brdf
    diffuse = direct * aDiffuseBrdf(s.albedo, s.roughness, d.LdotH, d.NdotL, s.NdotV);

    // sheen specular
    half sheen = direct * s.specularOcclusion * d.specularIntensity * FSchlick(s.f0, d.LdotH) * DCharlie(s.beckmannRoughness, d.NdotH) * VNeubelt(s.NdotV, d.NdotL);

    if (s.scatteringMask < 0.4h)
    {
        return;
    }

    else if (s.scatteringMask < 0.7h)
    {
        // energy conserved wrap diffuse
        diffuse = s.albedo * d.color * d.shadow.r;
        diffuse *= saturate((d.NdotLm + 0.5h) / 2.25h);
        diffuse *= saturate(normalize(s.albedo) + d.NdotL);

        // charlie 'sheen' specular
        /*
        specular = direct * FSchlick(s.f0, d.LdotH);
        specular *= DCharlie(s.beckmannRoughness, d.NdotH);
        specular *= VNeubelt(s.NdotV, d.NdotL);
        specular *= s.specularOcclusion * d.specularIntensity;
        */
        specular += sheen;
    }

    else if (s.scatteringMask == 1.0h)
    {
        specular += sheen;
    }

    /*
    half3 direct = d.color * d.shadow.r * d.NdotL;
    diffuse = direct * aDiffuseBrdf(s.albedo, s.roughness, d.LdotH, d.NdotL, s.NdotV);
    specular = direct * s.specularOcclusion * d.specularIntensity * aSpecularBrdf(s.f0, s.beckmannRoughness, d.LdotH, d.NdotH, d.NdotL, s.NdotV);
    */
}

/*
inline void aStandardDirect(ADirect d, ASurface s, out half3 diffuse, out half3 specular)
{
    #if defined(_PCF_TAPS_8) || defined(_PCF_TAPS_16) || defined(_PCF_TAPS_32) || defined(_PCF_TAPS_64)
        half3 rotationX = normalize(cross(d.direction, d.direction.zxy));
	    half3 rotationY = normalize(cross(d.direction, rotationX));

        float2 jitter = mad(tex2D(_ShadowJitterTexture, s.screenUv * _ScreenParams.xy * _ShadowJitterTexture_TexelSize.xy + _Time.yy).rg, 2.0f, -1.0f);
	    float2x2 rotationMatrix = float2x2(float2(jitter.x, -jitter.y), float2(jitter.y, jitter.x));

        #if defined(DIRECTIONAL)
            half radius = _DirLightPenumbra.y;
        #elif defined(SPOT)
            half radius = _SpotLightPenumbra.y;
        #elif defined(POINT)
            half radius = _PointLightPenumbra.y;
        #else
            half radius = 0.0h;
        #endif

        diffuse = 0.0h;
        specular = 0.0h;

        for(uint i = 0; i < PCF_NUM_TAPS; i ++)
        {
            float2 disk = mul(poissonDisk[i], rotationMatrix);

            #if defined(DIRECTIONAL)
                half3 lightVector = normalize(mad(rotationX * disk.x + rotationY * disk.y, radius, d.direction));
            #else
                half3 lightVector = normalize(mad(rotationX * disk.x + rotationY * disk.y, radius, d.direction / _LightPositionRange.w));
            #endif
            half3 halfVector = normalize(lightVector + s.viewDirWorld);

            half LdotH = aDotClamp(halfVector, lightVector);
            half NdotH = aDotClamp(s.normalWorld, halfVector);
            half NdotL = aDotClamp(s.normalWorld, lightVector);

            half3 direct = d.color * d.shadow.r * NdotL;

            diffuse += direct * aDiffuseBrdf(s.albedo, s.roughness, LdotH, NdotL, s.NdotV);
            specular += direct * s.specularOcclusion * d.specularIntensity * aSpecularBrdf(s.f0, s.beckmannRoughness, LdotH, NdotH, NdotL, s.NdotV);
        }

        diffuse /= PCF_NUM_TAPS;
        specular /= PCF_NUM_TAPS;
    #else
        half3 direct = d.color * d.shadow.r * d.NdotL;
        diffuse = direct * aDiffuseBrdf(s.albedo, s.roughness, d.LdotH, d.NdotL, s.NdotV);
        specular = direct * s.specularOcclusion * d.specularIntensity * aSpecularBrdf(s.f0, s.beckmannRoughness, d.LdotH, d.NdotH, d.NdotL, s.NdotV);
    #endif
}
*/

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

    return d.color * s.albedo * sss;
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
        return d.color * s.albedo * transmissionColor * transLight;
    #else
        half thickness = 2.0f * falloff * max(bias, d.shadow.g);
        half3 attenuation = tex2D(lut, float2(thickness * thickness, 0.5f));
        attenuation = attenuation * weight * saturate(0.3h - dot(s.ambientNormalWorld, d.direction));
        return d.color * s.albedo * attenuation;
    #endif
}

// thin layer transmittance for clothes
inline half3 aThinTransmission(ADirect d, ASurface s, sampler2D lut, half weight, half falloff, half bias)
{
    half attenuation = 0.25h * weight * saturate(0.3h - dot(s.ambientNormalWorld, d.direction));
    return d.color * s.albedo * attenuation * d.shadow.r;
}

#endif