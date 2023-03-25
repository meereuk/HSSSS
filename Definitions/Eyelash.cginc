#ifndef HSSSS_DEFINITIONS_EYELASH
#define HSSSS_DEFINITIONS_EYELASH

#include "Assets/HSSSS/Lighting/StandardSkin.cginc"
#include "Assets/HSSSS/Framework/Definition.cginc"

void aSurface(inout ASurface s)
{
    aSampleAlbedo(s);
    aSampleEmission(s);
    aUpdateNormalData(s);
}

#endif