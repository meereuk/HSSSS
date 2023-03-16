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
A_SAMPLER2D(_BumpMap);

half4 _Color;

half _Cutoff;
half _Metallic;
half _Smoothness;
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

#if defined(_SPECGLOSS_ON)
    A_SAMPLER2D(_SpecGlossMap);
#endif

#if defined(_OCCLUSION_ON)
    A_SAMPLER2D(_OcclusionMap);
    half _OcclusionStrength;
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

#if defined(_TRANSMISSION_ON)
    A_SAMPLER2D(_Thickness);
#endif

inline void aSampleAlbedo(inout ASurface s)
{
    half4 tex = tex2D(_MainTex, s.baseUv);
    s.opacity = _Color.a * tex.a;
    // 2-color sampling
    #if defined(_COLORMASK_ON)
        half colorMask = tex2D(_ColorMask, A_TRANSFORM_UV_SCROLL(s, _ColorMask)).g;
        s.baseColor = tex.rgb * lerp(_Color.rgb, _Color_3.rgb, colorMask);
    #else
        s.baseColor = _Color.rgb * tex.rgb;
    #endif
}

inline void aSampleDetailAlbedo(inout ASurface s)
{
    #if defined(_DETAILALBEDO_ON)
        half4 tex = tex2D(_DetailAlbedoMap, A_TRANSFORM_UV_SCROLL(s, _DetailAlbedoMap));
        s.baseColor = s.baseColor * tex.rgb;
    #endif
}

inline void aSampleAlphaClip(inout ASurface s)
{
    // alpha test
    #if defined(_ALPHATEST_ON)
        clip(s.opacity - _Cutoff);
    #endif

    #if defined(_ALPHASCALE_ON)
        clip(_Cutoff - s.opacity);
        s.opacity = smoothstep(0.0h, _Cutoff, s.opacity);
        clip(s.opacity - 0.001h);
    #endif

    // alpha hashed
    #if defined(_ALPHAHASHED_ON)
        half hash = tex2Dlod(_BlueNoise, 
        float4(s.screenUv * _ScreenParams.xy * _BlueNoise_TexelSize.xy + _FuzzBias * _Time.yy, 0.0f, 2.0f * s.viewDepth));
        clip(s.opacity - hash - _Cutoff);
    #endif
}

inline void aSampleSpecGloss(inout ASurface s)
{
    #if defined(_SPECGLOSS_ON)
        half4 tex = tex2D(_SpecGlossMap, A_TRANSFORM_UV_SCROLL(s, _SpecGlossMap));

        #if defined(_WORKFLOW_METALLIC)
            #if defined(_MATERIALTYPE_SKIN)
                half spec = aLuminance(tex.rgb);
                s.metallic = 0.0f;
                s.specularity = spec * aLuminance(_SpecColor);
                s.roughness = saturate(1.0h - _Metallic - spec * _Smoothness);
            #else
                s.metallic = aLuminance(tex.rgb) * _Metallic;
                s.roughness = 1.0h - tex.a * _Smoothness;
                s.specularity = aLuminance(_SpecColor);
            #endif
        #elif defined(_WORKFLOW_SPECULAR)
            s.metallic = 0.0h;
            s.roughness = 1.0h - tex.a * _Smoothness;
            s.specularColor = _SpecColor * tex.rgb * _Metallic;
        #endif
    #else
        #if defined(_WORKFLOW_METALLIC)
            s.metallic = _Metallic;
            s.roughness = 1.0h - _Smoothness;
            s.specularity = aLuminance(_SpecColor);
        #elif defined(_WORKFLOW_SPECULAR)
            s.metallic = 0.0h;
            s.roughness = 1.0h - _Smoothness;
            s.specularColor = aLuminance(_SpecColor) * _Metallic;
        #endif
    #endif
}

inline void aSampleOcclusion(inout ASurface s)
{
    #if defined(_OCCLUSION_ON)
        s.ambientOcclusion = aLerpOneTo(
            tex2D(_OcclusionMap, A_TRANSFORM_UV_SCROLL(s, _OcclusionMap)).g, _OcclusionStrength
        );
    #endif
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

inline void aSampleTransmission(inout ASurface s)
{
    #if defined(_TRANSMISSION_ON)
        s.transmission = 1.0h - tex2D(_Thickness, A_TRANSFORM_UV_SCROLL(s, _Thickness)).r;
    #else
        s.transmission = 0.0h;
    #endif
}

inline void aSampleScattering(inout ASurface s)
{
    #if defined(_MATERIALTYPE_SKIN)
        s.scatteringMask = 1.0h;
    #elif defined(_MATERIALTYPE_CLOTH)
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