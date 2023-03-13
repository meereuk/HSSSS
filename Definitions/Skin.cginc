#ifndef A_DEFINITIONS_SKIN_CGINC
#define A_DEFINITIONS_SKIN_CGINC

#define _SKINEFFECT_ON
#define _METALLIC_OFF

#define _EMISSION

#if defined(_WET_SPECGLOSS)
#define A_CLEARCOAT_ON
#endif

#include "Assets/HSSSS/Lighting/StandardSkin.cginc"
#include "Assets/HSSSS/Framework/Definition.cginc"

inline void aSampleBlurredTangent(inout ASurface s, float bias)
{
    s.blurredNormalTangent = UnpackScaleNormal(
        tex2Dbias(_BumpMap, float4(A_TRANSFORM_UV_SCROLL(s, _BumpMap), 0.0h, bias)), _BumpScale
    );
}

#if defined(_MICRODETAILS_ON)
A_SAMPLER2D(_DetailNormalMap_2);
A_SAMPLER2D(_DetailNormalMap_3);
A_SAMPLER2D(_DetailSkinPoreMap);
half _DetailNormalMapScale_2;
half _DetailNormalMapScale_3;

inline void aSampleMicroTangent(inout ASurface s)
{
    half3 normalWorld = s.normalWorld;
    half3 positionWorld = s.positionWorld;

    s.normalWorld = A_NORMAL_WORLD(s, s.normalTangent);

    half3 blend = abs(normalWorld);
    blend = normalize(max(blend, 0.00001h));
    blend /= (blend.x + blend.y + blend.z);

    half2 uvX = A_TRANSFORM_SCROLL(_DetailNormalMap_2, positionWorld.zy);
    half2 uvY = A_TRANSFORM_SCROLL(_DetailNormalMap_2, positionWorld.xz);
    half2 uvZ = A_TRANSFORM_SCROLL(_DetailNormalMap_2, positionWorld.xy);

    half3 tangentX = UnpackScaleNormal(tex2D(_DetailNormalMap_2, uvX), _DetailNormalMapScale_2);
    half3 tangentY = UnpackScaleNormal(tex2D(_DetailNormalMap_2, uvY), _DetailNormalMapScale_2);
    half3 tangentZ = UnpackScaleNormal(tex2D(_DetailNormalMap_2, uvZ), _DetailNormalMapScale_2);

    tangentX = half3(0.0h, tangentX.y, tangentX.x);
    tangentY = half3(tangentY.x, 0.0h, tangentY.y);
    tangentZ = half3(tangentZ.x, tangentZ.y, 0.0h);

    s.normalWorld = normalize(tangentX * blend.x + tangentY * blend.y + tangentZ * blend.z + s.normalWorld);

    uvX = A_TRANSFORM_SCROLL(_DetailNormalMap_3, positionWorld.zy);
    uvY = A_TRANSFORM_SCROLL(_DetailNormalMap_3, positionWorld.xz);
    uvZ = A_TRANSFORM_SCROLL(_DetailNormalMap_3, positionWorld.xy);

    tangentX = UnpackScaleNormal(tex2D(_DetailNormalMap_3, uvX), _DetailNormalMapScale_3);
    tangentY = UnpackScaleNormal(tex2D(_DetailNormalMap_3, uvY), _DetailNormalMapScale_3);
    tangentZ = UnpackScaleNormal(tex2D(_DetailNormalMap_3, uvZ), _DetailNormalMapScale_3);

    tangentX = half3(0.0h, tangentX.y, tangentX.x);
    tangentY = half3(tangentY.x, 0.0h, tangentY.y);
    tangentZ = half3(tangentZ.x, tangentZ.y, 0.0h);

    s.normalWorld = normalize(tangentX * blend.x + tangentY * blend.y + tangentZ * blend.z + s.normalWorld);

    s.blurredNormalTangent = A_NORMAL_TANGENT(s, s.normalWorld);
    s.ambientNormalWorld = s.normalWorld;

    uvX = A_TRANSFORM_SCROLL(_DetailSkinPoreMap, positionWorld.zy);
    uvY = A_TRANSFORM_SCROLL(_DetailSkinPoreMap, positionWorld.xz);
    uvZ = A_TRANSFORM_SCROLL(_DetailSkinPoreMap, positionWorld.xy);

    half poreX = tex2D(_DetailSkinPoreMap, uvX).r;
    half poreY = tex2D(_DetailSkinPoreMap, uvY).r;
    half poreZ = tex2D(_DetailSkinPoreMap, uvZ).r;

    half pore = poreX * blend.x + poreY * blend.y + poreZ * blend.z;
    
    s.ambientOcclusion = s.ambientOcclusion * lerp(1.0h, mad(pore, 0.2h, 0.8h), _OcclusionStrength);

    #if defined(_WET_SPECGLOSS)
        s.normalWorld = lerp(A_NORMAL_WORLD(s, A_FLAT_NORMAL), s.normalWorld, s.roughness);
    #endif

    aUpdateViewData(s);
}
#endif

inline void aSurface(inout ASurface s)
{
    aSampleAlbedo(s);
    aSampleDetailAlbedo(s);
    aSampleEmission(s);
    #if !defined(UNITY_PASS_SHADOWCASTER)
    #if !defined(UNITY_PASS_META)
        aSampleTransmission(s);
        aSampleScattering(s);
        aSampleSpecGloss(s);
        aSampleOcclusion(s);
        aSampleBumpTangent(s);
        aSampleBlendTangent(s);
        aSampleDetailTangent(s);
        #if defined(_MICRODETAILS_ON)
            aSampleMicroTangent(s);
        #else
            aSampleBlurredTangent(s, A_SKIN_BUMP_BLUR_BIAS);

            #if defined(_WET_SPECGLOSS)
                s.normalTangent = lerp(A_FLAT_NORMAL, s.normalTangent, s.roughness);
            #endif

            aUpdateNormalData(s);
        #endif
    #endif
    #endif
}

#endif