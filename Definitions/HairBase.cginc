#ifndef A_DEFINITIONS_HAIRBASE_CGINC
#define A_DEFINITIONS_HAIRBASE_CGINC

#define _METALLIC_OFF

#include "Assets/HSSSS/Lighting/Standard.cginc"
#include "Assets/HSSSS/Framework/Definition.cginc"

void aSurface(inout ASurface s)
{
    aSampleAlbedo(s);
    s.specularity = 0.0f;
    s.roughness = 1.0f;
}

#endif