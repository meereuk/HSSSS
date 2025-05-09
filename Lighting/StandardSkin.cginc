#ifndef A_LIGHTING_STANDARD_SKIN_CGINC
#define A_LIGHTING_STANDARD_SKIN_CGINC

#define A_SURFACE_CUSTOM_LIGHTING_DATA half3 blurredNormalTangent;

#include "Assets/HSSSS/Framework/Lighting.cginc"

half4 _DeferredSkinParams;

#if !defined(_SCREENSPACE_SSS)
    uniform sampler2D _DeferredBlurredNormalBuffer;
    uniform sampler2D _DeferredSkinLut;
#endif

#if defined(_FACEWORKS_TYPE2)
    uniform sampler2D _DeferredShadowLut;
    uniform half2 _DeferredShadowParams;
#endif

#if defined(_BAKED_THICKNESS)
    uniform half3 _DeferredSkinTransmissionAbsorption;
#else
    uniform sampler2D _DeferredTransmissionLut;
    uniform half _DeferredThicknessBias;
#endif

uniform sampler2D _DeferredTransmissionBuffer;
uniform half3 _DeferredSkinColorBleedAoWeights;
uniform half4 _DeferredTransmissionParams;

void aPreSurface(inout ASurface s)
{
    s.transmission = 0.0h;
    s.scatteringMask = 0.0h;
    s.blurredNormalTangent = A_FLAT_NORMAL;
}

void aPostSurface(inout ASurface s)
{
    s.ambientNormalWorld = s.normalWorld;
    s.blurredNormalTangent = s.normalTangent;
}

void aPackGbuffer(ASurface s, out half4 gbuffer0, out half4 gbuffer1, out half4 gbuffer2, out half4 gbuffer3)
{
    gbuffer0 = half4(s.albedo, s.ambientOcclusion);
    gbuffer1 = half4(s.f0, 1.0h - s.roughness);
    gbuffer2 = half4(s.normalWorld * 0.5h + 0.5h, 1.0h - s.scatteringMask);
    gbuffer3 = half4(s.emission, 1.0h - s.transmission);
}

void aUnpackGbuffer(inout ASurface s)
{
    s.specularOcclusion = aSpecularOcclusion(s.ambientOcclusion, aFresnel(s.NdotV));
    s.transmission = saturate(1.0h - tex2D(_DeferredTransmissionBuffer, s.screenUv));
    #if defined(_SCREENSPACE_SSS)
        s.ambientNormalWorld = s.normalWorld;
    #else
        s.ambientNormalWorld = mad(tex2D(_DeferredBlurredNormalBuffer, s.screenUv).xyz, 2.0h, -1.0h);
        s.ambientNormalWorld = s.scatteringMask == SHADING_MODEL_SKIN ? s.ambientNormalWorld : s.normalWorld;
        s.ambientNormalWorld = normalize(lerp(s.normalWorld, s.ambientNormalWorld, _DeferredSkinParams.w));
    #endif
}

void aDirect(ADirect d, ASurface s, out half3 diffuse, out half3 specular)
{
    aStandardDirect(d, s, diffuse, specular);

    // skin
    if (s.scatteringMask == SHADING_MODEL_SKIN)
    {
        /////////////////////////
        // pre-integrated brdf //
        /////////////////////////

        // jimenez (do nothing)
        #if defined(_SCREENSPACE_SSS)
        // faceworks type 2 (skin + shadow)
        #elif defined(_FACEWORKS_TYPE2)
            diffuse = aStandardSkin(d, s,
                _DeferredSkinLut, _DeferredShadowLut,
                _DeferredSkinParams.y, _DeferredSkinParams.z,
                _DeferredShadowParams.x, _DeferredShadowParams.y);
        // faceworks type 1 and penner (skin)
        #else
            diffuse = aStandardSkin(d, s,
                _DeferredSkinLut, _DeferredSkinParams.y, _DeferredSkinParams.z);
        #endif

        //////////////////////////////
        // subsurface transmittance //
        //////////////////////////////

        // pre-baked thickness map
        #if defined (_BAKED_THICKNESS)
            half3 absorption = exp((1.0h - sqrt(s.transmission)) * _DeferredSkinTransmissionAbsorption);

            half3 transmission = aStandardTransmission(d, s, absorption,
                _DeferredTransmissionParams.x, _DeferredTransmissionParams.z,
                _DeferredTransmissionParams.y, _DeferredTransmissionParams.w);
        // on-the-fly sampling from the shadowmap
        #else
            half3 transmission = aStandardTransmission(d, s, _DeferredTransmissionLut,
                _DeferredTransmissionParams.x, _DeferredTransmissionParams.y, _DeferredThicknessBias);
        #endif

        diffuse = (diffuse + transmission) * s.albedo;
        return;
    }

    // default
    else if (s.scatteringMask == SHADING_MODEL_STANDARD)
    {
        diffuse = diffuse * s.albedo;
        return;
    }

    // non-skin sss + thin layer transmittance
    else
    {
        half3 transmission = aThinTransmission(d, s, _DeferredTransmissionParams.x);
        diffuse = (diffuse + transmission) * s.albedo;
        return;
    }
}

half3 aIndirect(AIndirect i, ASurface s)
{
    // Color Bleed AO.
    // scatteringMask = 1.0f because it is g-buffer pass
    if (s.scatteringMask == 1.0h)
    {
        i.diffuse *= pow(s.ambientOcclusion, half3(1.0h, 1.0h, 1.0h) - _DeferredSkinColorBleedAoWeights);
    }
    return aStandardIndirect(i, s);
}

#endif
