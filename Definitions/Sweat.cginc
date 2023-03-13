#ifndef A_DEFINITIONS_SWEAT_CGINC
#define A_DEFINITIONS_SWEAT_CGINC

#include "Assets/HSSSS/Lighting/Standard.cginc"
#include "Assets/HSSSS/Framework/Definition.cginc"

sampler2D _DetailMask;

inline void aSurface(inout ASurface s)
{
    half mask = tex2D(_DetailMask, s.baseUv);

    half4 tex = tex2D(_MainTex, s.baseUv);

    s.baseColor = tex.rgb * _Color.rgb;
    s.opacity = tex.a * _Color.a;

    s.metallic = 0.0h;
    s.specularity = mask * _Metallic;
    s.roughness = 1.0h - _Smoothness;

    s.normalTangent = UnpackScaleNormal(tex2D(_BumpMap, s.baseUv), _BumpScale);

    aUpdateNormalData(s);
}

#endif