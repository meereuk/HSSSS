#ifndef HSSSS_DEFINITIONS_CORE
#define HSSSS_DEFINITIONS_CORE

#include "Assets/HSSSS/Lighting/StandardSkin.cginc"
#include "Assets/HSSSS/Framework/Definition.cginc"

void aSurface(inout ASurface s)
{
    aSampleAlbedo(s);
    aSampleEmission(s);
    #if !defined(UNITY_PASS_SHADOWCASTER)
        aSampleTransmission(s);
        aSampleScattering(s);
        aSampleSpecGloss(s);
        aUpdateNormalData(s);
    #endif
}

#endif