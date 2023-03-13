#ifndef COMMON_FEATURES_CGINC
#define COMMON_FEATURES_CGINC

#include "Assets/HSSSS/Config.cginc"
#include "Assets/HSSSS/Framework/Surface.cginc"
#include "Assets/HSSSS/Framework/Utility.cginc"

#include "UnityCG.cginc"
#include "UnityStandardBRDF.cginc"
#include "UnityStandardUtils.cginc"

#if defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON)
    #define A_ALPHA_BLENDING_ON 
#endif

#define A_SET_BASE_UV(s, TEX) \
    s.baseUv = A_TRANSFORM_UV(s, TEX); \
    s.baseTiling = TEX##_ST.xy;

#define A_SET_BASE_UV_SCROLL(s, TEX) \
    s.baseUv = A_TRANSFORM_UV_SCROLL(s, TEX); \
    s.baseTiling = TEX##_ST.xy;

A_SAMPLER2D(_MainTex);
A_SAMPLER2D(_SpecGlossMap);
A_SAMPLER2D(_OcclusionMap);
A_SAMPLER2D(_BumpMap);
A_SAMPLER2D(_Thickness);

half4 _Color;
half _Cutoff;
half _Metallic;
half _Smoothness;
half _OcclusionStrength;
half _BumpScale;

#if defined(_DETAILALBEDO_ON)
    A_SAMPLER2D(_DetailAlbedoMap);
#endif

#if defined(_COLORMASK_ON)
    A_SAMPLER2D(_ColorMask);
    half4 _Color_3;
#endif

#if defined(_EMISSION_ON)
    A_SAMPLER2D(_EmissionMap);
    half3 _EmissionColor;
#endif

#if defined(_ALPHAHASHED_ON)
    sampler2D _BlueNoise;
    float4 _BlueNoise_TexelSize;
    float _FuzzBias;
#endif

#if defined(_BLENDNORMAL_ON)
    A_SAMPLER2D(_BlendNormalMap);
    half _BlendNormalMapScale;
#endif

#if defined(_DETAILNORMAL_ON)
    A_SAMPLER2D(_DetailNormalMap);
    half _DetailNormalMapScale;
#endif

inline void aSampleAlbedo(inout ASurface s)
{
    half4 tex = tex2D(_MainTex, s.baseUv);

    s.opacity = _Color.a * tex.a;

    // alpha test
    #if defined(_ALPHATEST_ON)
        clip(s.opacity - _Cutoff);
    #endif

    // alpha hashed
    #if defined(_ALPHAHASHED_ON)
        half hash = tex2Dlod(_BlueNoise, 
        float4(s.screenUv * _ScreenParams.xy * _BlueNoise_TexelSize.xy + _FuzzBias * _Time.yy, 0.0f, 2.0f * s.viewDepth));
        clip(s.opacity - hash - _Cutoff);
    #endif

    // 2-color sampling
    #if defined(_COLORMASK_ON)
        half colorMask = tex2D(_ColorMask, A_TRANSFORM_UV_SCROLL(s, _ColorMask)).g;
        s.baseColor = tex.rgb * lerp(_Color.rgb, _Color_3.rgb, colorMask);
    #else
        s.baseColor = _Color.rgb * tex.rgb;
    #endif

    /*
    // alpha blend
    #if defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON) || defined(_ALPHATEST_ON) || defined(_ALPHAHASHED_ON) || defined (A_FINAL_GBUFFER_ON)
        s.opacity = _Color.a * tex.a;
    #endif

    // alpha test
    #if defined(_ALPHATEST_ON)
        clip(s.opacity - _Cutoff);
    #endif

    // alpha hashed
    #if defined(_ALPHAHASHED_ON)
        half hash = tex2Dlod(_BlueNoise, 
        float4(s.screenUv * _ScreenParams.xy * _BlueNoise_TexelSize.xy + _FuzzBias * _Time.yy, 0.0f, 2.0f * s.viewDepth));
        clip(s.opacity - hash - _Cutoff);
    #endif
    */
}

inline void aSampleDetailAlbedo(inout ASurface s)
{
    #if defined(_DETAILALBEDO_ON)
        half4 tex = tex2D(_DetailAlbedoMap, A_TRANSFORM_UV_SCROLL(s, _DetailAlbedoMap));
        s.baseColor = s.baseColor * tex.rgb;
    #endif
}

inline void aSampleSpecGloss(inout ASurface s)
{
    half2 tex = tex2D(_SpecGlossMap, A_TRANSFORM_UV_SCROLL(s, _SpecGlossMap)).ra;

    #if defined(_METALLIC_OFF)
        #if defined(_SKINEFFECT_ON)
            s.specularity = _SpecColor.r;
            #if defined(_WET_SPECGLOSS)
                s.baseColor = s.baseColor * lerp(1.0h, 0.9h, tex.r * _Smoothness);
                s.roughness = 1.0h - lerp(_Metallic, _Smoothness, tex.r);

                s.clearCoatWeight = 1.0h - s.roughness;
                s.clearCoatRoughness = 0.0h;
            #else
                s.roughness = 1.0h - _Smoothness * tex.g;
            #endif
        #elif defined(_SPECCOLOR_ON)
            s.specularity = _Metallic;
            s.specularColor = _SpecColor;
            s.roughness = 1.0h - _Smoothness * tex.g;
        #else
            s.specularity = _Metallic * tex.r;
            s.roughness = 1.0h - _Smoothness * tex.g;
        #endif
    #else
        s.metallic = _Metallic * tex.r;
        s.specularity = _SpecColor.r;
        s.roughness = 1.0h - _Smoothness * tex.g;
    #endif
}

inline void aSampleOcclusion(inout ASurface s)
{
    s.ambientOcclusion = aLerpOneTo(
        tex2D(_OcclusionMap, A_TRANSFORM_UV_SCROLL(s, _OcclusionMap)).g, _OcclusionStrength
    );
}

inline void aSampleBumpTangent(inout ASurface s)
{
    s.normalTangent = UnpackScaleNormal(
        tex2D(_BumpMap, A_TRANSFORM_UV_SCROLL(s, _BumpMap)), _BumpScale
    );
}

// blend normal
inline void aSampleBlendTangent(inout ASurface s)
{
    #if defined(_BLENDNORMAL_ON)
        s.normalTangent = BlendNormals(
            s.normalTangent, UnpackScaleNormal(
                tex2D(_BlendNormalMap, A_TRANSFORM_UV_SCROLL(s, _BlendNormalMap)), _BlendNormalMapScale
            )
        );
    #endif
}

// detail normal
inline void aSampleDetailTangent(inout ASurface s)
{
    #if defined(_DETAILNORMAL_ON)
        s.normalTangent = BlendNormals(
            s.normalTangent, UnpackScaleNormal(
                tex2D(_DetailNormalMap, A_TRANSFORM_UV_SCROLL(s, _DetailNormalMap)), _DetailNormalMapScale
            )
        );
    #endif
}

// emission
inline void aSampleEmission(inout ASurface s)
{
    #if defined(_EMISSION_ON)
        half4 emission = tex2D(_EmissionMap, A_TRANSFORM_UV_SCROLL(s, _EmissionMap));
        s.emission = _EmissionColor * emission.rgb * emission.a;
    #endif
}

/*
// rimlight
#if defined(_RIMLIGHT)
half3 _RimColor;
half _RimWeight;
half _RimPower;
half _RimBias;

inline void aSampleRimLight(inout ASurface s)
{
    s.emission += _RimColor * (_RimWeight * aRimLight(_RimBias, _RimPower, s.NdotV));
}
#endif
*/

inline void aSampleTransmission(inout ASurface s)
{
    #if defined(UNITY_PASS_DEFERRED) && defined(_SKINEFFECT_ON)
        s.transmission = 1.0h - tex2D(_Thickness, A_TRANSFORM_UV_SCROLL(s, _Thickness)).r;
    #else
        s.transmission = 0.0h;
    #endif
}

inline void aSampleScattering(inout ASurface s)
{
    #if defined(UNITY_PASS_DEFERRED) && defined(_SKINEFFECT_ON)
        s.scatteringMask = 1.0h;
    #elif defined(UNITY_PASS_DEFERRED) && defined(_THINLAYER_ON)
        s.scatteringMask = 0.67h;
    #else
        s.scatteringMask = 0.0h;
    #endif
}

inline void aSetDefaultBaseUv(inout ASurface s)
{
    A_SET_BASE_UV_SCROLL(s, _MainTex);
}

inline void aSetBaseUv(inout ASurface s, float2 baseUv)
{
    s.baseUv = baseUv;
}

#endif