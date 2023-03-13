#ifndef A_DEFINITIONS_THIN_CGINC
#define A_DEFINITIONS_THIN_CGINC

#include "Assets/HSSSS/Lighting/StandardSkin.cginc"
#include "Assets/HSSSS/Framework/Definition.cginc"


void aSurface(inout ASurface s)
{
    s.baseColor = _Color.rgb;
    s.opacity = _Color.a;

    s.specularity = 0.5h;
    s.roughness = 1.0h;

    s.baseColor *= tex2D(_MainTex, s.baseUv);
    s.scatteringMask = 0.67h;

    aSampleBumpTangent(s);
    aUpdateNormalData(s);
}

#endif