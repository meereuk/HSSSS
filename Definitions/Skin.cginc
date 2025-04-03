#ifndef HSSSS_DEFINITIONS_SKIN
#define HSSSS_DEFINITIONS_SKIN

#define _SKINSPECULAR_ON
#define A_SCREEN_UV_ON

#include "Assets/HSSSS/Lighting/StandardSkin.cginc"
#include "Assets/HSSSS/Framework/Definition.cginc"

void aSurface(inout ASurface s)
{
    aSampleAlbedo(s);
    aSampleEmission(s);
    #ifndef UNITY_PASS_SHADOWCASTER
        aSampleTransmission(s);
        aSampleScattering(s);
        aSampleSpecGloss(s);
        aSampleOcclusion(s);
        aSampleBumpTangent(s);
        aSampleBlendTangent(s);
        aSampleDetailTangent(s);
        #ifdef _MICRODETAILS_ON
            aSampleMicroTangent(s);
        #endif
        aUpdateNormalData(s);
    #endif
}

#endif