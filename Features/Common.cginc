#ifndef A_FRAMEWORK_FEATURE_CGINC
#define A_FRAMEWORK_FEATURE_CGINC

#include "Assets/Alloy/Shaders/Config.cginc"
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
A_SAMPLER2D(_DetailAlbedoMap);
A_SAMPLER2D(_SpecGlossMap);
A_SAMPLER2D(_OcclusionMap);
A_SAMPLER2D(_BumpMap);
A_SAMPLER2D(_BlendNormalMap);
A_SAMPLER2D(_DetailNormalMap);
A_SAMPLER2D(_EmissionMap);
A_SAMPLER2D(_Thickness);

half4 _Color;
half3 _RimColor;
half3 _EmissionColor;

half _Cutoff;
half _Metallic;
half _Smoothness;
half _OcclusionStrength;
half _BumpScale;
half _BlendNormalMapScale;
half _DetailNormalMapScale;

half _RimWeight;
half _RimPower;
half _RimBias;
half _Emission;

#if defined(_COLORMASK_ON)
A_SAMPLER2D(_ColorMask);
half4 _Color_3;
#endif

inline void aSampleAlbedo(inout ASurface s)
{
    half4 tex = tex2D(_MainTex, s.baseUv);

    #if defined(_COLORMASK_ON)
    half mask = tex2D(_ColorMask, A_TRANSFORM_UV_SCROLL(s, _ColorMask)).g;
    s.baseColor = lerp(_Color.rgb * tex.rgb, _Color_3.rgb * tex.rgb , mask);
    #else
    s.baseColor = _Color.rgb * tex.rgb;
    #endif

    #if defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON) || defined(_ALPHATEST_ON) || defined(_ALPHAHASHED_ON)
    s.opacity = _Color.a * tex.a;
    #endif

    #if defined(_ALPHATEST_ON)
    #if defined(_CUTOFF_MAX)
    clip(s.opacity - 1.0h);
    #else
    clip(s.opacity - _Cutoff);
    #endif
    #endif
}

inline void aSampleDetailAlbedo(inout ASurface s)
{
    s.baseColor *= tex2D(_DetailAlbedoMap, A_TRANSFORM_UV_SCROLL(s, _DetailAlbedoMap));
}

inline void aSampleSpecGloss(inout ASurface s)
{
    half2 tex = tex2D(_SpecGlossMap, A_TRANSFORM_UV_SCROLL(s, _SpecGlossMap)).ra;
    #if defined(_METALLIC_OFF)
        #if defined(_SKINEFFECT_ON)
            s.specularity = _SpecColor.r * tex.r;
            #if defined(_WET_SPECGLOSS)
                s.baseColor = s.baseColor * lerp(1.0h, 0.8h, tex.r * _Smoothness);
                s.roughness = 1.0h - lerp(_Metallic, _Smoothness, tex.r);

                s.clearCoatWeight = 1.0h - s.roughness;
                s.clearCoatRoughness = 0.0h;
            #else
                s.roughness = 1.0h - _Smoothness * tex.g;
            #endif
        #else
            s.specularity = _Metallic * tex.r;
            s.roughness = 1.0h - _Smoothness * tex.g;
        #endif
    #else
        s.metallic = _Metallic;
        s.specularity = _SpecColor * tex.r;
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

inline void aSampleBlendTangent(inout ASurface s)
{
    s.normalTangent = BlendNormals(
        s.normalTangent, UnpackScaleNormal(
            tex2D(_BlendNormalMap, A_TRANSFORM_UV_SCROLL(s, _BlendNormalMap)), _BlendNormalMapScale
        )
    );
}

inline void aSampleDetailTangent(inout ASurface s)
{
    s.normalTangent = BlendNormals(
        s.normalTangent, UnpackScaleNormal(
            tex2D(_DetailNormalMap, A_TRANSFORM_UV_SCROLL(s, _DetailNormalMap)), _DetailNormalMapScale
        )
    );
}

inline void aSampleTransmission(inout ASurface s)
{
    s.transmission = 1.0h - tex2D(_Thickness, A_TRANSFORM_UV_SCROLL(s, _Thickness)).r;
}

inline void aSampleScattering(inout ASurface s)
{
    s.scatteringMask = 1.0h;
}

inline void aSampleEmission(inout ASurface s)
{
    s.emission = _Emission * _EmissionColor * tex2D(_EmissionMap, A_TRANSFORM_UV_SCROLL(s, _EmissionMap));
}

inline void aSampleRimLight(inout ASurface s)
{
    s.emission += _RimColor * (_RimWeight * aRimLight(_RimBias, _RimPower, s.NdotV));
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