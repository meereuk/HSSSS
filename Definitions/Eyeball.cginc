#ifndef A_DEFINITIONS_EYEBALL_CGINC
#define A_DEFINITIONS_EYEBALL_CGINC

#if defined(UNITY_PASS_DEFERRED)
#if !defined(A_VIEW_VECTOR_TANGENT_ON)
    #define A_VIEW_VECTOR_TANGENT_ON
#endif
#endif

#define A_CLEARCOAT_ON

#include "Assets/HSSSS/Lighting/StandardSkin.cginc"
#include "Assets/HSSSS/Framework/Definition.cginc"

sampler2D _ScleraBaseMap;
sampler2D _ScleraVeinMap;
sampler2D _HeightMap;

half _Parallax;
half _PupilSize;
half _VeinScale;

inline void EyeParallaxOcclusion(inout ASurface s)
{
    float2 offset = float2(0.0f, 0.0f);
    float parallaxLimit = -length(s.viewDirTangent.xy) / s.viewDirTangent.z;

    parallaxLimit *= _Parallax;
    
    float2 offsetDirTangent = normalize(s.viewDirTangent.xy);
    float2 maxOffset = offsetDirTangent * parallaxLimit;

    int numSamples = (int)lerp(25.0f, 10.0f, s.NdotV);
    int currentSample = 0;

    float stepSize = 1.0f / (float)numSamples;

    float currentRayHeight = 1.0f;
    float2 lastOffset = float2(0.0f, 0.0f);

    float lastSampledHeight = 1.0f;
    float currentSampledHeight = 1.0f;

    float2 dx = ddx_fine(s.baseUv);
    float2 dy = ddy_fine(s.baseUv);

    while (currentSample < numSamples)
    {
        currentSampledHeight = tex2Dgrad(_HeightMap, s.baseUv + offset, dx, dy);

        if (currentSampledHeight > currentRayHeight)
        {
            float delta1 = currentSampledHeight - currentRayHeight;
            float delta2 = (currentRayHeight + stepSize) - lastSampledHeight;
            float ratio = delta1 / (delta1 + delta2);

            offset = lerp(offset, lastOffset, ratio);

            currentSample = numSamples + 1;
        }
        else
        {
            currentSample++;
            currentRayHeight -= stepSize;
            lastOffset = offset;
            offset += stepSize * maxOffset;
            lastSampledHeight = currentSampledHeight;
        }
    }

    float mask = tex2D(_MainTex, s.baseUv).a;

    offset *= mask;
    s.uv01 += (offset / s.baseTiling).xyxy;
    aSetBaseUv(s, s.baseUv + offset);

    float2 centeredUv = frac(s.baseUv) + float2(-0.5f, -0.5f);
    aSetBaseUv(s, s.baseUv - centeredUv * mask * _PupilSize);
}

void aSurface(inout ASurface s)
{
    float4 uv01 = s.uv01;

    #if defined(UNITY_PASS_DEFERRED)
        EyeParallaxOcclusion(s);
        s.scatteringMask = 1.0h;
        s.transmission = 0.2h;
    #else
        s.scatteringMask = 0.0h;
        s.transmission = 0.0h;
    #endif

    half4 iris = tex2D(_MainTex, s.baseUv) * _Color;

    half3 scleraBase = tex2D(_ScleraBaseMap, s.baseUv);
    half3 scleraVein = tex2D(_ScleraVeinMap, s.baseUv);
    half3 sclera = lerp(scleraBase, scleraVein, _VeinScale) * _SpecColor;

    half irisMask = iris.a;
    s.baseColor = lerp(sclera, iris, irisMask);

    aSampleEmission(s);

    #if !defined(UNITY_PASS_SHADOWCASTER)
    #if !defined(UNITY_PASS_META)
        s.metallic = 0.0h;
        s.ambientOcclusion = 1.0;

        s.specularity = _Metallic;
        s.roughness = 1.0h - _Smoothness;

        s.clearCoatWeight = irisMask;
        s.clearCoatRoughness = 0.0h;

        s.mask = 1.0h;

        half heightMask = tex2D(_HeightMap, s.baseUv);

        s.normalTangent = UnpackScaleNormal(
            tex2D(_BumpMap, A_TRANSFORM_UV_SCROLL(s, _BumpMap)), lerp(_BumpScale, 0.0h, heightMask)
        );

        #if defined(_DETAILNORMAL_ON)
            s.normalTangent = BlendNormals(
                s.normalTangent, UnpackScaleNormal(
                    tex2D(_DetailNormalMap, A_TRANSFORM_UV_SCROLL(s, _DetailNormalMap)), _DetailNormalMapScale
                )
            );
        #endif

        aUpdateNormalData(s);
    #endif
    #endif

    s.uv01 = uv01;
}

#endif