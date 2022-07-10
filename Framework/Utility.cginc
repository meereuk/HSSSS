// Alloy Physical Shader Framework
// Copyright 2013-2016 RUST LLC.
// http://www.alloy.rustltd.com/

/////////////////////////////////////////////////////////////////////////////////
/// @file Utility.cginc
/// @brief Minimum functions and constants common to surfaces and particles.
/////////////////////////////////////////////////////////////////////////////////

#ifndef A_FRAMEWORK_UTILITY_CGINC
#define A_FRAMEWORK_UTILITY_CGINC

#include "Assets/Alloy/Shaders/Config.cginc"

#include "UnityShaderVariables.cginc"

/// A value close to zero.
/// This is used for preventing NaNs in cases where you can divide by zero.
#define A_EPSILON (1e-6f)

/// Flat normal in tangent space.
#define A_FLAT_NORMAL (half3(0.0h, 0.0h, 1.0h))

/// Defines all texture transform uniform variables, inlcuding additional transforms.
/// Spin is in radians.
#define A_SAMPLER2D(name) \
    sampler2D name; \
    float4 name##_ST; \
    float2 name##Velocity; \
    float name##Spin; \
    float name##UV;

// NOTE: To make it rotate around a "center" point, the order of operations
// needs to be offset, rotate, scale. So that means that we have to apply 
// offset & scroll first divided by tiling. Then when we apply tiling later 
// it will cancel.

/// Applies our scrolling effect.
#define A_SCROLL(name) ((name##Velocity * _Time.y + name##_ST.zw) / name##_ST.xy)

/// Applies our spinning effect.
#define A_SPIN(name, tex) (aRotateTextureCoordinates(name##Spin * _Time.y, tex.xy))

/// Applies Unity texture transforms plus our spinning effect. 
#define A_TRANSFORM_SPIN(name, tex) (A_SPIN(name, tex + (name##_ST.zw / name##_ST.xy)) * name##_ST.xy)

/// Applies Unity texture transforms plus our spinning and scrolling effects.
#define A_TRANSFORM_SCROLL(name, tex) ((tex + A_SCROLL(name)) * name##_ST.xy)

/// Applies Unity texture transforms plus our spinning and scrolling effects.
#define A_TRANSFORM_SCROLL_SPIN(name, tex) (A_SPIN(name, tex + A_SCROLL(name)) * name##_ST.xy)

/// Applies 2D texture rotation around the point (0.5,0.5) in UV-space.
/// @param  rotation    Rotation in radians.
/// @param  texcoords   Texture coordinates to be rotated.
/// @return             Rotated texture coordinates.
float2 aRotateTextureCoordinates(
    float rotation,
    float2 texcoords)
{
    // Texture Rotation
    // cf http://forum.unity3d.com/threads/rotation-of-texture-uvs-directly-from-a-shader.150482/#post-1031763 
    float2 centerOffset = float2(0.5f, 0.5f);
    float sinTheta = sin(rotation);
    float cosTheta = cos(rotation);
    float2x2 rotationMatrix = float2x2(cosTheta, -sinTheta, sinTheta, cosTheta);
    return mul(texcoords - centerOffset, rotationMatrix) + centerOffset;
}

half aDotClamp(
    half2 x,
    half2 y)
{
    return saturate(dot(x, y));
}

half aDotClamp(
    half3 x,
    half3 y)
{
    return saturate(dot(x, y));
}

half aDotClamp(
    half4 x,
    half4 y)
{
    return saturate(dot(x, y));
}

/// Interpolate from one to another value.
half aLerpOneTo(
    half b,
    half alpha)
{
    // Use lerp intrinsic for better optimization.
    return lerp(1.0h, b, alpha); 
}

/// Interpolate from the color white to another color.
half3 aLerpWhiteTo(
    half3 b,
    half alpha)
{
    // Use lerp intrinsic for better optimization.
    return lerp(half3(1.0h, 1.0h, 1.0h), b, alpha);
}

/// Calculates a linear color's luminance.
/// @param  color   Linear LDR color.
/// @return         Color's chromaticity.
half aLuminance(
    half3 color)
{
    // Linear-space luminance coefficients.
    // cf https://en.wikipedia.org/wiki/Luma_(video)
    return dot(color, half3(0.2126h, 0.7152h, 0.0722h));
}

/// Calculates a linear color's chromaticity.
/// @param  color   Linear LDR color.
/// @return         Color's chromaticity.
half3 aChromaticity(
    half3 color)
{
    return color / max(aLuminance(color), A_EPSILON).rrr;
}

/// Clamp HDR output to avoid excess bloom and blending errors.
/// @param  value   Linear HDR value.
/// @return         Range-limited HDR color [0,32].
half aHdrClamp(
    half value)
{
#if A_USE_HDR_CLAMP
    value = min(value, A_HDR_CLAMP_MAX_INTENSITY);
#endif
    return value;
}

/// Clamp HDR output to avoid excess bloom and blending errors.
/// @param  color   Linear HDR color.
/// @return         Range-limited HDR color [0,32].
half3 aHdrClamp(
    half3 color)
{
#if A_USE_HDR_CLAMP
    color = min(color, (A_HDR_CLAMP_MAX_INTENSITY).rrr);
#endif
    return color;
}

/// Clamp HDR output to avoid excess bloom and blending errors.
/// @param  color   Linear HDR color.
/// @return         Range-limited HDR color [0,32].
half4 aHdrClamp(
    half4 color)
{
#if A_USE_HDR_CLAMP
    color = min(color, (A_HDR_CLAMP_MAX_INTENSITY).rrrr);
#endif
    return color;
}

/// Used to calculate a rim light effect.
/// @param  bias    Bias rim towards constant emission.
/// @param  power   Rim falloff.
/// @param  NdotV   Normal and view vector dot product.
/// @return         Rim lighting.
half aRimLight(
    half bias, 
    half power, 
    half NdotV) 
{
    return lerp(bias, 1.0h, pow(1.0h - NdotV, power));
}

/// Applies four closest lights per-vertex using Alloy's attenuation.
/// @param  lightPosX       Four lights' position X in world-space.
/// @param  lightPosY       Four lights' position Y in world-space.
/// @param  lightPosZ       Four lights' position Z in world-space.
/// @param  lightColor0     First light color.
/// @param  lightColor1     Second light color.
/// @param  lightColor2     Third light color.
/// @param  lightColor3     Fourth light color.
/// @param  lightAttenSq    Four lights' Unity attenuation.
/// @param  pos             Position in world-space.
/// @param  normal          Normal in world-space.
/// @return                 Per-vertex direct lighting.
float3 aShade4PointLights(
    float4 lightPosX, 
    float4 lightPosY, 
    float4 lightPosZ,
    float3 lightColor0, 
    float3 lightColor1, 
    float3 lightColor2, 
    float3 lightColor3,
    float4 lightAttenSq,
    float3 pos, 
    float3 normal)
{
    // to light vectors
    float4 toLightX = lightPosX - pos.x;
    float4 toLightY = lightPosY - pos.y;
    float4 toLightZ = lightPosZ - pos.z;
    // squared lengths
    float4 lengthSq = 0;
    lengthSq += toLightX * toLightX;
    lengthSq += toLightY * toLightY;
    lengthSq += toLightZ * toLightZ;
    // NdotL
    float4 ndotl = 0;
    ndotl += toLightX * normal.x;
    ndotl += toLightY * normal.y;
    ndotl += toLightZ * normal.z;
    // correct NdotL
    float4 corr = rsqrt(lengthSq);
    ndotl = max (float4(0,0,0,0), ndotl * corr);
    
    // attenuation
    // NOTE: Get something close to Alloy attenuation by undoing Unity's calculations.
    // http://forum.unity3d.com/threads/easiest-way-to-change-point-light-attenuation-with-deferred-path.254337/#post-1681835
    float4 invRangeSqr = lightAttenSq / 25.0f;
    
    // Inverse Square attenuation, with light range falloff.
    // cf http://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf p12
    float4 ratio2 = lengthSq * invRangeSqr;
    float4 num = saturate(float4(1.0f, 1.0f, 1.0f, 1.0f) - (ratio2 * ratio2));
    float4 atten = (num * num) / (lengthSq + float4(1.0f, 1.0f, 1.0f, 1.0f));
    
    float4 diff = ndotl * atten;
    // final color
    float3 col = 0;
    col += lightColor0 * diff.x;
    col += lightColor1 * diff.y;
    col += lightColor2 * diff.z;
    col += lightColor3 * diff.w;
    return col;
}

/// Applies 4 closest lights per-vertex using Alloy's attenuation.
/// @param  positionWorld   Position in world-space.
/// @param  normalWorld     Normal in world-space.
/// @return                 Per-vertex direct lighting.
float3 aVertexLights(
    float3 positionWorld, 
    float3 normalWorld) 
{
    return aShade4PointLights(
        unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
        unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
        unity_4LightAtten0, positionWorld, normalWorld);
}

#endif // A_FRAMEWORK_UTILITY_CGINC
