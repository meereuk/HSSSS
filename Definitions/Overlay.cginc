#ifndef A_DEFINITIONS_OVERLAY_CGINC
#define A_DEFINITIONS_OVERLAY_CGINC

#define A_FINAL_GBUFFER_ON

#if defined(_SKINEFFECT_ON)
    #include "Assets/HSSSS/Lighting/StandardSkin.cginc"
#else
    #include "Assets/HSSSS/Lighting/Standard.cginc"
#endif
#include "Assets/HSSSS/Framework/Definition.cginc"

void aSurface(inout ASurface s)
{
    aSampleAlbedo(s);
    aSampleDetailAlbedo(s);
    #if defined(_ALPHASCALE_ON)
        clip(_Cutoff - s.opacity);
        s.opacity = smoothstep(0.0h, _Cutoff, s.opacity);
        clip(s.opacity - 0.001h);
    #endif
    #if defined(_SKINEFFECT_ON)
        s.transmission = 0.2h;
        s.scatteringMask = 1.0h;
    #else
        s.transmission = 0.0h;
        s.scatteringMask = 0.0h;
    #endif
    aSampleSpecGloss(s);
    aSampleOcclusion(s);
    aSampleBumpTangent(s);
    aSampleDetailTangent(s);
    aUpdateNormalData(s);
}

void aFinalGbuffer(ASurface s, inout half4 diffuseOcclusion, inout half4 specSmoothness, inout half4 normalScattering, inout half4 emissionTransmission)
{
    #ifdef A_DECAL_ALPHA_FIRSTPASS
    diffuseOcclusion.a = s.opacity;
    specSmoothness.a = s.opacity;
    normalScattering.a = s.opacity;
    emissionTransmission.a = s.opacity;
    #else
    diffuseOcclusion.a *= s.opacity;
    specSmoothness.a *= s.opacity;
    normalScattering.a *= s.opacity;
    emissionTransmission.a *= s.opacity;
    #endif
}

#endif