#ifndef A_DEFINITIONS_WATER_CGINC
#define A_DEFINITIONS_WATER_CGINC

#define A_SCREEN_UV_ON

#include "Assets/HSSSS/Lighting/Water.cginc"
#include "Assets/HSSSS/Framework/Definition.cginc"

A_SAMPLER2D(_DetailNormalMap);
half _DetailNormalMapScale;

void aSurface(inout ASurface s)
{
    s.baseColor = _Color.rgb;
    s.opacity = _Color.a;

    s.metallic = 0.0h;
    s.specularity = _Metallic;
    s.roughness = 1.0h - _Smoothness;

    float2 normalUv = A_TRANSFORM_SCROLL(_BumpMap, s.positionWorld.xz);

    s.normalTangent = UnpackScaleNormal(
        tex2D(_BumpMap, A_TRANSFORM_SCROLL(_BumpMap, s.positionWorld.xz)), _BumpScale);
        
    s.normalTangent = BlendNormals(
        s.normalTangent, UnpackScaleNormal(tex2D(_DetailNormalMap, A_TRANSFORM_SCROLL(_DetailNormalMap, s.positionWorld.xz)), _DetailNormalMapScale));

    aUpdateNormalData(s);
    aUpdateViewData(s);
}

#endif