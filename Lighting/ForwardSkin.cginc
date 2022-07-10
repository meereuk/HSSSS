// Alloy Physical Shader Framework
// Copyright 2013-2016 RUST LLC.
// http://www.alloy.rustltd.com/

///////////////////////////////////////////////////////////////////////////////
/// @file PreIntegratedSkin.cginc
/// @brief Pre-Integrated Skin lighting model. Forward-only.
///////////////////////////////////////////////////////////////////////////////

#ifndef A_LIGHTING_PRE_INTEGRATED_SKIN_CGINC
#define A_LIGHTING_PRE_INTEGRATED_SKIN_CGINC

// NOTE: The example shader used calculated curvature, but it looked terrible. 
// We're using a translucency map, and getting much better results.
#define A_SURFACE_CUSTOM_LIGHTING_DATA \
    half3 blurredNormalTangent; 

#include "Assets/HSSSS/Framework/Lighting.cginc"

sampler2D _SssBrdfTex;

half _SssBias;
half _SssScale;
half _SssAoSaturation;
half _SssBumpBlur;

half3 _TransColor;
half _TransScale;
half _TransPower;
half _TransDistortion;

void aPreSurface(inout ASurface s)
{
    s.scatteringMask = 1.0h;
    s.blurredNormalTangent = A_FLAT_NORMAL;
}

void aPostSurface(inout ASurface s)
{
    // Blurred normals for indirect diffuse and direct scattering.
    s.blurredNormalTangent = normalize(lerp(s.normalTangent, s.blurredNormalTangent, s.scatteringMask * _SssBumpBlur));
    s.ambientNormalWorld = A_NORMAL_WORLD(s, s.blurredNormalTangent);
}

half3 aDirect(ADirect d, ASurface s)
{
    half3 transmissionColor = _TransScale * _TransColor * s.transmission.rrr;

    half3 scattering = aStandardSkin(d, s, _SssBrdfTex, _SssBias, _SssScale);
    half3 transmission = aStandardTransmission(d, s, transmissionColor, 1.0h, _TransDistortion, _TransPower, 0.0h);

    return aStandardDirect(d, s) + scattering + transmission;
}

half3 aIndirect(AIndirect i, ASurface s)
{	
    half saturation = s.scatteringMask * _SssAoSaturation;

    s.albedo = pow(s.albedo, (1.0h + saturation) - saturation * s.ambientOcclusion);
    return aStandardIndirect(i, s);
}

#endif
