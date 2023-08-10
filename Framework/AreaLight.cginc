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
uniform Texture2D _ShadowJitterTexture;
uniform SamplerState sampler_ShadowJitterTexture;
uniform float4 _ShadowJitterTexture_TexelSize;

// random number generator
inline float GradientNoise(float2 uv)
{
    return frac(sin(dot(uv, float2(12.9898, 78.2333))) * 43758.5453123);
}

inline float3 SampleNoise(float2 uv)
{
    return _ShadowJitterTexture.Sample(sampler_ShadowJitterTexture, uv * _ShadowJitterTexture_TexelSize.xy * _ScreenParams.xy).xyz;
}

// gram-schmidt process
inline float3x3 GramSchmidtMatrix(float2 uv, float3 axis)
{
    float3 jitter = normalize(mad(SampleNoise(uv), 2.0f, -1.0f));
    float3 tangent = normalize(jitter - axis * dot(jitter, axis));
    float3 bitangent = normalize(cross(axis, tangent));

    return float3x3(tangent, bitangent, axis);
}
#endif