#ifndef A_LIGHTING_STANDARD_CGINC
#define A_LIGHTING_STANDARD_CGINC

#include "Assets/HSSSS/Framework/Lighting.cginc"

void aPreSurface(inout ASurface s)
{
}

void aPostSurface(inout ASurface s)
{
    s.ambientNormalWorld = s.normalWorld;
}

void aPackGbuffer(ASurface s, out half4 diffuseOcclusion, out half4 specularSmoothness, out half4 normalScattering, out half4 emissionTransmission)
{
    diffuseOcclusion = half4(s.albedo, s.specularOcclusion);
    specularSmoothness = half4(s.f0, 1.0h - s.roughness);
    normalScattering = half4(s.normalWorld * 0.5h + 0.5h, 1.0h);
    emissionTransmission = half4(s.emission, 1.0h);
}

void aUnpackGbuffer(inout ASurface s)
{

}

half3 aDirect(ADirect d, ASurface s)
{
    return aStandardDirect(d, s);
}

half3 aIndirect(AIndirect i, ASurface s)
{
    return aStandardIndirect(i, s);
}

#endif
