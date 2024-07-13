#ifndef HSSSS_COMMON_FEATURES_CGINC
#define HSSSS_COMMON_FEATURES_CGINC

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
A_SAMPLER2D(_ColorMask);
A_SAMPLER2D(_DetailAlbedoMap);

A_SAMPLER2D(_EmissionMap);

A_SAMPLER2D(_BumpMap);
A_SAMPLER2D(_BlendNormalMap);
A_SAMPLER2D(_DetailNormalMap);

A_SAMPLER2D(_SpecGlossMap);
A_SAMPLER2D(_OcclusionMap);

A_SAMPLER2D(_Thickness);

half4 _Color;
half4 _Color_3;
half3 _EmissionColor;

half _MaterialType;
half _Anisotropy;

half _Metallic;
half _Smoothness;
half _OcclusionStrength;
half _FresnelAlpha;

half _BumpScale;
half _BlendNormalMapScale;
half _DetailNormalMapScale;

#if defined(_ALPHATEST_ON)
    half _Cutoff;
#endif

#if defined(_ALPHAHASHED_ON)
    uniform uint _FrameCount;
    sampler3D _BlueNoise;
    half _FuzzBias;
    half _Cutoff;
    half _Hash;
#endif

inline void aSampleAlbedo(inout ASurface s)
{
    half4 tex = tex2D(_MainTex, s.baseUv);
    s.baseColor = tex.rgb * _Color.rgb;
    s.opacity = tex.a * _Color.a;
}

inline void aSampleTwoColorAlbedo(inout ASurface s)
{
    half4 tex = tex2D(_MainTex, s.baseUv);
    half mask = tex2D(_ColorMask, A_TRANSFORM_UV_SCROLL(s, _ColorMask)).g;
    s.baseColor = lerp(_Color.rgb, _Color_3.rgb, mask) * tex.rgb;
    s.opacity = lerp(_Color.a, _Color_3.a, mask) * tex.a;
}

inline void aSampleFresnelAlpha(inout ASurface s)
{
    half NdotV = saturate(dot(s.normalWorld, s.viewDirWorld));
    s.opacity = lerp(s.opacity, 1.0h, _FresnelAlpha * pow(1.0h - NdotV, 4));
}

inline void aSampleDetailAlbedo(inout ASurface s)
{
    half4 tex = tex2D(_DetailAlbedoMap, A_TRANSFORM_UV_SCROLL(s, _DetailAlbedoMap));
    s.baseColor *= tex.rgb;
    s.opacity *= tex.a;
}

inline void aSampleAlphaClip(inout ASurface s)
{
    // alpha test
    #if defined(_ALPHATEST_ON)
        clip(s.opacity - _Cutoff);
    #endif

    // alpha hashed
    #if defined(_ALPHAHASHED_ON)
        float z = ((float)((_FrameCount + 32) % 64) * 0.015625f + 0.0078125f) * _FuzzBias + s.vertexColor.x;
        half hash = tex3D(_BlueNoise, float3(s.screenUv.xy * _ScreenParams.xy * 0.0078125f + 0.5f, z));
        clip(s.opacity - mad(hash, _Hash, _Cutoff));
    #endif
}

inline void aSampleSpecGloss(inout ASurface s)
{
    half4 tex = tex2D(_SpecGlossMap, A_TRANSFORM_UV_SCROLL(s, _SpecGlossMap));

    #if defined(_WORKFLOW_SPECULAR)
        s.metallic = 0.0h;
        s.specularity = 0.0h;
        s.specularColor = _SpecColor.rgb * tex.rgb * _Metallic;
        s.roughness = 1.0h - tex.a * _Smoothness;
    #elif defined(_SKINSPECULAR_ON)
        half gloss = aLuminance(tex.rgb);
        s.metallic = 0.0h;
        s.specularity = aLuminance(_SpecColor.rgb);
        s.roughness = 1.0h - lerp(_Metallic, _Smoothness, gloss);
    #else
        s.metallic = _Metallic * aLuminance(tex.rgb);
        s.specularity = aLuminance(_SpecColor.rgb);
        s.roughness = 1.0h - tex.a * _Smoothness;
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

inline void aSampleEmission(inout ASurface s)
{
    half4 emission = tex2D(_EmissionMap, A_TRANSFORM_UV_SCROLL(s, _EmissionMap));
    s.emission = _EmissionColor * emission.rgb * emission.a;
    s.emission += max(0.0h, s.baseColor - saturate(s.baseColor));
}

inline void aSampleTransmission(inout ASurface s)
{
    if (_MaterialType == 1.0h)
    {
        s.transmission = saturate(mad(_Anisotropy, 0.5h, 0.5h));
    }

    else
    {
        s.transmission = 1.0h - tex2D(_Thickness, A_TRANSFORM_UV_SCROLL(s, _Thickness)).r;
    }
}

inline void aSampleScattering(inout ASurface s)
{
    s.scatteringMask = _MaterialType / 3.0h;
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