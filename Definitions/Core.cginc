#ifndef A_DEFINITIONS_CORE_CGINC
#define A_DEFINITIONS_CORE_CGINC

#include "Assets/HSSSS/Lighting/StandardSkin.cginc"
#include "Assets/HSSSS/Framework/Definition.cginc"

#if defined(UNITY_PASS_SHADOWCASTER) && defined(_THINLAYER_ON)
    #define UNITY_STANDARD_USE_DITHER_MASK
#endif

void aSurface(inout ASurface s)
{
    aSampleAlbedo(s);
    aSampleDetailAlbedo(s);
    aSampleEmission(s);
    #if !defined(UNITY_PASS_SHADOWCASTER)
    #if !defined(UNITY_PASS_META)
        aSampleTransmission(s);
        aSampleScattering(s);
        aSampleSpecGloss(s);
        aSampleOcclusion(s);
        aSampleBumpTangent(s);
        aSampleBlendTangent(s);
        aSampleDetailTangent(s);
        aUpdateNormalData(s);
    #endif
    #endif
}

#endif