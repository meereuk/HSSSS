#ifndef A_DEFINITIONS_EYEBALL_CGINC
#define A_DEFINITIONS_EYEBALL_CGINC

#define A_SPECULAR_TINT_ON
#define A_CLEARCOAT_ON
#define _SKINEFFECT_ON
#define _METALLIC_OFF

#if defined(UNITY_PASS_DEFERRED)
#if !defined(A_VIEW_VECTOR_TANGENT_ON)
    #define A_VIEW_VECTOR_TANGENT_ON
#endif
#endif

#include "Assets/HSSSS/Lighting/StandardSkin.cginc"
#include "Assets/HSSSS/Framework/Definition.cginc"

sampler2D _ScleraTex;
half _Parallax;
half _PupilSize;

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

    float2 dx = ddx(s.baseUv);
    float2 dy = ddy(s.baseUv);

    while (currentSample < numSamples)
    {
        // height map from the iris texture alpha
        currentSampledHeight = -tex2Dgrad(_MainTex, s.baseUv + offset, dx, dy).a;

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
    #endif

    half4 iris = tex2D(_MainTex, s.baseUv) * _Color;
    half3 sclera = tex2D(_ScleraTex, s.baseUv) * _SpecColor;

    half irisMask = iris.a;

    s.baseColor = lerp(sclera, iris, irisMask);

    #if !defined(UNITY_PASS_SHADOWCASTER)
    #if !defined(UNITY_PASS_META)
    s.metallic = 0.0h;
    s.ambientOcclusion = 1.0;

    half2 specgloss = tex2D(_SpecGlossMap, s.baseUv).ra;
    specgloss = lerp(half2(1.0h, 1.0h), specgloss, irisMask);

    s.specularity = _Metallic * specgloss.x;
    s.roughness = 1.0h - (_Smoothness * specgloss.y);
    s.specularTint = irisMask;

    s.clearCoatWeight = 1.0h;
    s.clearCoatRoughness = 0.0h;

    s.scatteringMask = 1.0h;
    s.transmission = 0.2h;

    s.mask = 1.0h;

    aSampleBumpTangent(s);
    aSampleDetailTangent(s);
    aUpdateNormalData(s);
    #endif
    #endif

    s.uv01 = uv01;
}

#endif
