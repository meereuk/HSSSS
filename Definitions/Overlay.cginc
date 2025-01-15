#ifndef HSSSS_DEFINITIONS_OVERLAY
#define HSSSS_DEFINITIONS_OVERLAY

#define A_SCREEN_UV_ON

#ifdef _FORWARDONLY_OVERLAY
    uniform sampler2D _SSDOBentNormalTexture;
    uniform uint _UseAmbientOcclusion;
#endif

#include "Assets/HSSSS/Lighting/StandardSkin.cginc"
#include "Assets/HSSSS/Framework/Definition.cginc"

void aSurface(inout ASurface s)
{
    aSampleAlbedo(s);
    aSampleEmission(s);
    aSampleFresnelAlpha(s);
    aSampleAlphaClip(s);
    aSampleTransmission(s);
    aSampleScattering(s);
    aSampleSpecGloss(s);
    aSampleOcclusion(s);
    #ifdef _FORWARDONLY_OVERLAY
        if (_UseAmbientOcclusion == 1)
        {
            s.ambientOcclusion *= tex2D(_SSDOBentNormalTexture, s.screenUv).w;
        }
    #endif
    aSampleBumpTangent(s);
    aSampleDetailTangent(s);
    aUpdateNormalData(s);
}

#endif