#ifndef A_DEFINITIONS_PBRSP_CGINC
#define A_DEFINITIONS_PBRSP_CGINC

#include "Assets/HSSSS/Lighting/Standard.cginc"
#include "Assets/HSSSS/Framework/Definition.cginc"

void aSurface(inout ASurface s)
{
    aSampleAlbedo(s);
    #if !defined(UNITY_PASS_SHADOWCASTER)
    aSampleDetailAlbedo(s);
    #if !defined(UNITY_PASS_META)
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