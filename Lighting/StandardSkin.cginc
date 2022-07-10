#ifndef A_LIGHTING_STANDARD_SKIN_CGINC
#define A_LIGHTING_STANDARD_SKIN_CGINC

#define A_SURFACE_CUSTOM_LIGHTING_DATA \
    half3 blurredNormalTangent; 

#include "Assets/HSSSS/Framework/Lighting.cginc"

sampler2D _DeferredBlurredNormalBuffer;
sampler2D _DeferredSkinLut;
half4 _DeferredSkinParams;

#if defined(_FACEWORKS_TYPE2)
sampler2D _DeferredShadowLut;
half2 _DeferredShadowParams;
#endif

half3 _DeferredSkinColorBleedAoWeights;

sampler2D _DeferredTransmissionBuffer;
half3 _DeferredSkinTransmissionAbsorption;
half4 _DeferredTransmissionParams;

void aPreSurface(inout ASurface s)
{
    s.scatteringMask = 1.0h;
    s.blurredNormalTangent = A_FLAT_NORMAL;
}

void aPostSurface(inout ASurface s)
{
    s.scatteringMask *= _DeferredSkinParams.x;
    
    // Blurred normals for indirect diffuse and direct scattering.
    s.blurredNormalTangent = normalize(lerp(s.normalTangent, s.blurredNormalTangent, s.scatteringMask * _DeferredSkinParams.w));
    s.ambientNormalWorld = A_NORMAL_WORLD(s, s.blurredNormalTangent);
}

void aPackGbuffer
(
    ASurface s,
    out half4 diffuseOcclusion,
    out half4 specularSmoothness,
    out half4 normalScattering,
    out half4 emissionTransmission
)
{
    // Pass the sharp normals to avoid double-blurring.
    diffuseOcclusion = half4(s.albedo, s.specularOcclusion);
    specularSmoothness = half4(s.f0, 1.0h - s.roughness);
    normalScattering = half4(s.normalWorld * 0.5h + 0.5h, 1.0h - s.scatteringMask);
    emissionTransmission = half4(s.emission, 1.0h - s.transmission);
}

void aUnpackGbuffer(inout ASurface s)
{
    s.transmission = 1.0h - tex2D(_DeferredTransmissionBuffer, s.screenUv).a;
    s.ambientNormalWorld = tex2D(_DeferredBlurredNormalBuffer, s.screenUv).xyz * 2.0h - 1.0h;
    s.ambientNormalWorld = normalize(lerp(s.normalWorld, s.ambientNormalWorld, s.scatteringMask * _DeferredSkinParams.w));
}

half3 aDirect(ADirect d, ASurface s)
{
    half3 absorption = exp((1.0h - sqrt(s.transmission)) * _DeferredSkinTransmissionAbsorption);
    half3 transmissionColor = lerp(s.transmission.rrr, absorption, s.scatteringMask);

    #if defined(_FACEWORKS_TYPE2)
        half3 scattering = aStandardSkin(d, s,
            _DeferredSkinLut, _DeferredShadowLut,
            _DeferredSkinParams.y, _DeferredSkinParams.z,
            _DeferredShadowParams.x, _DeferredShadowParams.y);
    #else
        half3 scattering = aStandardSkin(d, s,
            _DeferredSkinLut, _DeferredSkinParams.y, _DeferredSkinParams.z);
    #endif

    half3 transmission = aStandardTransmission(d, s, transmissionColor,
        _DeferredTransmissionParams.x, _DeferredTransmissionParams.z,
        _DeferredTransmissionParams.y, _DeferredTransmissionParams.w);
    
    return aStandardDirect(d, s) + scattering + transmission;

    /*
    half thickness = d.shadow.g;
    half blurredNdL = dot(s.ambientNormalWorld, d.direction);

    half3 transmit = 0.05h * exp2(-4096.0f * thickness * thickness) * saturate(0.0h - blurredNdL);
    transmit *= s.albedo * d.color * normalize(exp(_DeferredSkinTransmissionAbsorption)) * s.scatteringMask;
    return aStandardDirect(d, s) + sss;// +transmit;
    */
}

half3 aIndirect(AIndirect i, ASurface s)
{
    // Color Bleed AO.
    i.diffuse *= pow(s.ambientOcclusion, half3(1.0h, 1.0h, 1.0h) - (_DeferredSkinColorBleedAoWeights * s.scatteringMask));
    s.ambientOcclusion = 1.0h;
    return aStandardIndirect(i, s);
}

#endif
