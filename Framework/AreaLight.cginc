#ifndef HSSSS_AREALIGHT_CGINC
#define HSSSS_AREALIGHT_CGINC

// x : blocker search radius
// y : light radius (tangent for directional)
// z : minimum penumbra radius (also fixed pcf penumbra radius)
uniform float3 _DirLightPenumbra;
uniform float3 _SpotLightPenumbra;
uniform float3 _PointLightPenumbra;
uniform uint   _SoftShadowNumIter;

// jittering texture for the randomized rotation
uniform sampler2D _ShadowJitterTexture;
uniform float4 _ShadowJitterTexture_TexelSize;

// NdotL lookup table for area light
uniform sampler2D _AreaLightLUT;

// random number generator
inline float GradientNoise(float2 uv)
{
    return frac(sin(dot(uv, float2(12.9898, 78.2333))) * 43758.5453123);
}

// gram-schmidt process
inline float3x3 GramSchmidtMatrix(float2 uv, float3 axis)
{
    float3 jitter = float3(
        GradientNoise(mad(uv, 1.3f, _Time.xx)),
        GradientNoise(mad(uv, 1.6f, _Time.xx)),
        GradientNoise(mad(uv, 1.9f, _Time.xx))
    );

    jitter = normalize(mad(jitter, 2.0f, -1.0f));

    float3 tangent = normalize(jitter - axis * dot(jitter, axis));
    float3 bitangent = normalize(cross(axis, tangent));

    return float3x3(tangent, bitangent, axis);
}
#endif