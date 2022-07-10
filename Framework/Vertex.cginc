// Alloy Physical Shader Framework
// Copyright 2013-2016 RUST LLC.
// http://www.alloy.rustltd.com/

///////////////////////////////////////////////////////////////////////////////
/// @file Vertex.cginc
/// @brief Vertex input data from the application.
///////////////////////////////////////////////////////////////////////////////

#ifndef A_FRAMEWORK_VERTEX_CGINC
#define A_FRAMEWORK_VERTEX_CGINC

#if defined(DYNAMICLIGHTMAP_ON) || defined(UNITY_PASS_META)
    #define A_UV2_ON
#endif

#if defined(UNITY_PASS_SHADOWCASTER) || defined(UNITY_PASS_META)
    #define A_SURFACE_DATA_LITE
#endif

#ifndef A_SURFACE_DATA_LITE
    #define A_TANGENT_TO_WORLD_ON
#endif

#if defined(A_LIGHTING_OFF) || !(defined(UNITY_PASS_FORWARDBASE) || defined(UNITY_PASS_DEFERRED))
    #define A_GI_OFF
#endif

#ifdef A_GI_OFF
    #define A_GI_DATA(n)
#else
    #define A_GI_DATA(n) half4 giData : TEXCOORD##n;
#endif

#ifdef A_SURFACE_DATA_LITE
    #define A_VERTEX_DATA(A, B, C, D, E, F, G) \
        float4 texcoords    : TEXCOORD##A; \
        half4 color         : TEXCOORD##B;
#else
    #define A_VERTEX_DATA(A, B, C, D, E, F, G) \
        float4 texcoords                    : TEXCOORD##A; \
        half4 viewDirWorldAndDepth          : TEXCOORD##B; \
        half4 tangentToWorldAndScreenUv0    : TEXCOORD##C; \
        half4 tangentToWorldAndScreenUv1    : TEXCOORD##D; \
        half4 tangentToWorldAndScreenUv2    : TEXCOORD##E; \
        float4 positionWorld                : TEXCOORD##F; \
        half4 color                         : TEXCOORD##G;
#endif

/// Vertex input from the model data.
struct AVertex 
{
    float4 vertex : POSITION;
    float2 uv0 : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    half3 normal : NORMAL;
#ifdef A_UV2_ON
    float2 uv2 : TEXCOORD2;
#endif
#ifdef A_TANGENT_TO_WORLD_ON
    half4 tangent : TANGENT;
#endif
    half4 color : COLOR;
};

#endif // A_FRAMEWORK_VERTEX_CGINC
