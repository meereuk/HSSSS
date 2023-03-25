#ifndef HSSSS_DEFINITIONS_CORE
#define HSSSS_DEFINITIONS_CORE

#include "Assets/HSSSS/Lighting/StandardSkin.cginc"
#include "Assets/HSSSS/Framework/Definition.cginc"

#if defined(_ALPHAHASHED_ON)
    #define A_SCREEN_UV_ON
#endif

void aSurface(inout ASurface s)
{
    aSampleAlbedo(s);
    aSampleDetailAlbedo(s);
    aSampleEmission(s);
    aSampleAlphaClip(s);
    #if !defined(UNITY_PASS_SHADOWCASTER)
        aSampleTransmission(s);
        aSampleScattering(s);
        aSampleSpecGloss(s);
        aSampleOcclusion(s);
        aSampleBumpTangent(s);
        aSampleBlendTangent(s);
        aSampleDetailTangent(s);
        aUpdateNormalData(s);
    #endif
}

#endif