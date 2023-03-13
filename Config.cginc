// Alloy Physical Shader Framework
// Copyright 2013-2016 RUST LLC.
// http://www.alloy.rustltd.com/

/////////////////////////////////////////////////////////////////////////////////
/// @file Config.cginc
/// @brief User configuration options.
/////////////////////////////////////////////////////////////////////////////////

#ifndef A_CONFIG_CGINC
#define A_CONFIG_CGINC

/// Flag provided for third-party integration.
#define A_VERSION 3.35

/// Enables clamping of all shader outputs to prevent blending and bloom errors.
#define A_USE_HDR_CLAMP 1

/// Max HDR intensity for lighting and emission.
#define A_HDR_CLAMP_MAX_INTENSITY 100.0

/// Enables capping tessellation quality via the global _MinEdgeLength property.
#define A_USE_TESSELLATION_MIN_EDGE_LENGTH 0

/// Enables tube area lights. Can be disabled to improve sphere light performance.
#define A_USE_TUBE_LIGHTS 0

/// Enables the Unity behavior for light cookies.
#define A_USE_UNITY_LIGHT_COOKIES 0

/// Enables the Unity behavior for attenuation.
#define A_USE_UNITY_ATTENUATION 1

// ---- Unity config -----
#ifndef UNITY_SAMPLE_FULL_SH_PER_PIXEL
#define UNITY_SAMPLE_FULL_SH_PER_PIXEL 1
#endif


#endif // A_CONFIG_CGINC
