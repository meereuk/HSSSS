#ifndef A_LIGHTING_UNLIT_CGINC
#define A_LIGHTING_UNLIT_CGINC

#define A_LIGHTING_OFF

#include "Assets/HSSSS/Framework/Lighting.cginc"

void aPreSurface(inout ASurface s)
{
}

void aPostSurface(inout ASurface s)
{
    s.ambientNormalWorld = s.normalWorld;
}

void aPackGbuffer(
    ASurface s,
    out half4 diffuseOcclusion,
    out half4 specularSmoothness,
    out half4 normalScattering,
    out half4 emissionTransmission)
{
    diffuseOcclusion = 0.0h;
    specularSmoothness = 0.0h;
    normalScattering = half4(s.normalWorld * 0.5h + 0.5h, 1.0h);
    emissionTransmission = half4(s.emission, 1.0h);
}

void aUnpackGbuffer(inout ASurface s)
{
}

void aDirect(ADirect d, ASurface s, out half3 diffuse, out half3 specular)
{
    diffuse = 0.0h;
    specular = 0.0h;
}

half3 aIndirect(AIndirect i, ASurface s)
{
    return 0.0h;
}

#endif
