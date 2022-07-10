#ifndef A_DEFINITIONS_SKIN_CGINC
#define A_DEFINITIONS_SKIN_CGINC

#define _SKINEFFECT_ON
#define _METALLIC_OFF

#if defined(_WET_SPECGLOSS)
    #define A_CLEARCOAT_ON
#endif

#include "Assets/HSSSS/Lighting/ForwardSkin.cginc"
#include "Assets/HSSSS/Framework/Definition.cginc"

inline void aSampleBlurredTangent(inout ASurface s, float bias)
{
    s.blurredNormalTangent = UnpackScaleNormal(
        tex2Dbias(_BumpMap, float4(A_TRANSFORM_UV_SCROLL(s, _BumpMap), 0.0h, bias)), _BumpScale
    );
}

void aSurface(inout ASurface s)
{
    aSampleAlbedo(s);
    //#if !defined(UNITY_PASS_SHADOWCASTER)
    //#if !defined(UNITY_PASS_META)
    aSampleTransmission(s);
    aSampleScattering(s);
    aSampleSpecGloss(s);
    aSampleOcclusion(s);
    aSampleBumpTangent(s);
    aSampleBlendTangent(s);
    aSampleDetailTangent(s);
    aSampleBlurredTangent(s, A_SKIN_BUMP_BLUR_BIAS);
    aUpdateNormalData(s);
    //#endif
    //#endif
}

#endif