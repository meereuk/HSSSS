#ifndef A_DEFINITIONS_HAIR_CGINC
#define A_DEFINITIONS_HAIR_CGINC

#if defined(UNITY_PASS_DEFERRED)
    #define _SPECCOLOR_ON
#endif

#define A_SCREEN_UV_ON

#if defined(UNITY_PASS_FORWARDBASE) || defined(UNITY_PASS_FORWARDADD)
    #include "Assets/HSSSS/Lighting/Hair.cginc"

    half _AnisoAngle;
    half _WrapDiffuse;
    half _HighlightShift;
    half _HighlightWidth;
#else
    #include "Assets/HSSSS/Lighting/Standard.cginc"
#endif

#include "Assets/HSSSS/Framework/Definition.cginc"

sampler2D _BlueNoise;
float4 _BlueNoise_TexelSize;
float _FuzzBias;

void aSurface(inout ASurface s)
{
    half4 albedo = tex2D(_MainTex, s.baseUv);
    s.opacity = albedo.a;
    /*
    #if defined(UNITY_PASS_SHADOWCASTER)
        clip(s.opacity - _Cutoff);
    #else
        // hashed alpha
        half hash = tex2D(_BlueNoise, s.screenUv * _ScreenParams.xy * _BlueNoise_TexelSize.xy + _FuzzBias * _Time.yy);
        clip(s.opacity - lerp(_Cutoff, hash, _Metallic));

        // albedo
        s.baseColor = albedo * _Color;

        // specular & glossiness
        half gloss = tex2D(_SpecGlossMap, A_TRANSFORM_UV_SCROLL(s, _SpecGlossMap)).r;

        s.specularity = 1.0h;
        s.roughness = 1.0h - _Smoothness * gloss;

        #if defined(UNITY_PASS_DEFERRED)
            s.metallic = 0.0h;
            s.specularColor = _SpecColor;
        #else
            s.highlightTint = _SpecColor;
            // anisotropic rotations
            half theta = radians(_AnisoAngle);
            s.highlightTangent = half3(cos(theta), sin(theta), 0.0h);

            s.highlightShift = _HighlightShift;
            s.highlightWidth = _HighlightWidth;

            // wrap lighting
            s.diffuseWrap = _WrapDiffuse;
        #endif

        aSampleDetailAlbedo(s);
        aSampleEmission(s);
        aSampleOcclusion(s);
        aSampleBumpTangent(s);
        aUpdateNormalData(s);
    #endif
    */
}

#endif