#ifndef A_DEFINITIONS_HAIR_CGINC
#define A_DEFINITIONS_HAIR_CGINC

#define _METALLIC_OFF

#include "Assets/HSSSS/Lighting/Hair.cginc"
#include "Assets/HSSSS/Framework/Definition.cginc"

A_SAMPLER2D(_NoiseMap);
A_SAMPLER2D(_ShiftMap);

half _WrapDiffuse;
half _AnisoAngle;
half _HighlightShift0;
half _HighlightWidth0;
half _HighlightShift1;
half _HighlightWidth1;

half4 _SpecColor_3;

inline void aSampleHairAlbedo(inout ASurface s)
{
    half4 tex = tex2D(_MainTex, s.baseUv);
    s.baseColor = _Color.rgb * tex.rgb;
    #if defined(_ALPHATEST_ON)
    s.opacity = _Color.a * tex.a;
    clip(s.opacity - _Cutoff);
    #if defined(_CUTOFF_MAX)
    clip(s.opacity - 1.0h);
    #endif
    #endif
    #if defined(_ALPHABLEND_ON)
    half scale = 1.0h / _Cutoff;
    s.opacity = clamp(_Color.a * tex.a * scale, 0.0h, 1.0h);
    #endif
}

void aSampleHairEffect(inout ASurface s)
{
    half noise = tex2D(_NoiseMap, A_TRANSFORM_UV_SCROLL(s, _NoiseMap)).g;
    half shift = tex2D(_ShiftMap, A_TRANSFORM_UV_SCROLL(s, _ShiftMap)).g - 0.5h;

    s.highlightTint0 = noise * _SpecColor_3;
    s.highlightShift0 = _HighlightShift0 + shift;
    s.highlightWidth0 = _HighlightWidth0;
    s.highlightTint1 = _SpecColor;
    s.highlightShift1 = _HighlightShift1 + shift;
    s.highlightWidth1 = _HighlightWidth1;

    half theta = radians(_AnisoAngle);
    s.diffuseWrap = _WrapDiffuse;
    s.highlightTangent = half3(cos(theta), sin(theta), 0.0h);
}

void aSurface(inout ASurface s)
{
    aSampleHairAlbedo(s);
    #if !defined(UNITY_PASS_SHADOWCASTER)
    #if !defined(UNITY_PASS_META)
    aSampleSpecGloss(s);
    aSampleOcclusion(s);
    aSampleHairEffect(s);
    aSampleBumpTangent(s);
    aUpdateNormalData(s);
    #endif
    #endif
}

#endif