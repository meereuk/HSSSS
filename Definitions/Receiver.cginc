#ifndef HSSSS_DEFINITIONS_RECEIVER
#define HSSSS_DEFINITIONS_RECEIVER

#define A_SCREEN_UV_ON

#include "Assets/HSSSS/Lighting/StandardSkin.cginc"
#include "Assets/HSSSS/Framework/Definition.cginc"

void aSurface(inout ASurface s)
{
    s.albedo = 1.0h;
    s.emission = 0.0h;
    s.metallic = 0.0h;
    s.specularity = 0.0h;
    s.roughness = 1.0h;
    s.ambientOcclusion = 1.0h;

    aUpdateNormalData(s);
}

#endif