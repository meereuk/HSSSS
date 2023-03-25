#ifndef HSSSS_DEFINITIONS_OVERLAY
#define HSSSS_DEFINITIONS_OVERLAY

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
}

#endif