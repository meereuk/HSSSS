#ifndef HSSSS_DEFINITIONS_OVERLAY
#define HSSSS_DEFINITIONS_OVERLAY

#if defined(_ALPHAHASHED_ON)
    #define A_SCREEN_UV_ON
#endif

#include "Assets/HSSSS/Lighting/StandardSkin.cginc"
#include "Assets/HSSSS/Framework/Definition.cginc"

void aSurface(inout ASurface s)
{
    aSampleAlbedo(s);
    aSampleEmission(s);
    aSampleTransmission(s);
    aSampleScattering(s);
    aSampleSpecGloss(s);
    aSampleOcclusion(s);
    aSampleBumpTangent(s);
    aUpdateNormalData(s);
    aSampleFresnelAlpha(s);
    aSampleAlphaClip(s);
}

#endif