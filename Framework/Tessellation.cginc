// Alloy Physical Shader Framework
// Copyright 2013-2016 RUST LLC.
// http://www.alloy.rustltd.com/

///////////////////////////////////////////////////////////////////////////////
/// @file Tessellation.cginc
/// @brief Callbacks and data structures for tessellation.
///////////////////////////////////////////////////////////////////////////////

#ifndef A_FRAMEWORK_TESSELLATION_CGINC
#define A_FRAMEWORK_TESSELLATION_CGINC

#include "Assets/HSSSS/Config.cginc"
#include "Assets/HSSSS/Framework/Vertex.cginc"
#include "Assets/HSSSS/Framework/Utility.cginc"

#include "HLSLSupport.cginc"
#include "UnityCG.cginc"
#include "Tessellation.cginc"
#include "Lighting.cginc"
#include "UnityShaderVariables.cginc"

#if defined(A_TESSELLATION_ON) && defined(UNITY_CAN_COMPILE_TESSELLATION)	
    #if defined(_TESSELLATIONMODE_COMBINED)
        #define _TESSELLATIONMODE_DISPLACEMENT
        #define _TESSELLATIONMODE_PHONG
    #endif
    
    struct AVertexToTessellation {
        float4 vertex : INTERNALTESSPOS;
        half3 normal : NORMAL;
        float2 uv0 : TEXCOORD0;
        float2 uv1 : TEXCOORD1;
    #ifdef A_UV2_ON
        float2 uv2 : TEXCOORD2;
    #endif
    #ifdef A_TANGENT_TO_WORLD_ON
        half4 tangent : TANGENT;
    #endif
        half4 color 	: COLOR;
    };
    
    float _EdgeLength;
    
    #if A_USE_TESSELLATION_MIN_EDGE_LENGTH
        float _MinEdgeLength;
    #endif

    #ifdef _TESSELLATIONMODE_DISPLACEMENT
        A_SAMPLER2D(_DispTex);
        float _Displacement;
    #endif
    #ifdef _TESSELLATIONMODE_PHONG
        float _Phong;
    #endif

    #if defined(_VERTEXWRAP_ON)
        sampler2D _CameraDepthTexture;
    #endif

    // NOTE: Forward-declared here so we can share Domain shader.
    void aVertexShader(AVertex v, out AVertexToFragment o, out float4 opos : SV_POSITION);
    
    // tessellation hull constant shader
    UnityTessellationFactors aHullConstantTessellation(
        InputPatch<AVertexToTessellation, 3> v) 
    {
        UnityTessellationFactors o;
        float4 tf;
        AVertex vi[3];
        
        vi[0].vertex = v[0].vertex;
        vi[0].normal = v[0].normal;
        vi[0].uv0 = v[0].uv0;
        vi[0].uv1 = v[0].uv1;

        vi[1].vertex = v[1].vertex;
        vi[1].normal = v[1].normal;
        vi[1].uv0 = v[1].uv0;
        vi[1].uv1 = v[1].uv1;

        vi[2].vertex = v[2].vertex;
        vi[2].normal = v[2].normal;
        vi[2].uv0 = v[2].uv0;
        vi[2].uv1 = v[2].uv1;

    #ifdef A_UV2_ON
        vi[0].uv2 = v[0].uv2;
        vi[1].uv2 = v[1].uv2;
        vi[2].uv2 = v[2].uv2;
    #endif
    #ifdef A_TANGENT_TO_WORLD_ON
        vi[0].tangent = v[0].tangent;
        vi[1].tangent = v[1].tangent;
        vi[2].tangent = v[2].tangent;
    #endif
        vi[0].color = v[0].color;
        vi[1].color = v[1].color;
        vi[2].color = v[2].color;
    
        float maxDisplacement = 0.0f;
    
    #ifdef _TESSELLATIONMODE_DISPLACEMENT
        maxDisplacement = 1.5f * 0.01f * _Displacement;
    #endif
    
        float edgeLength = _EdgeLength;
        
    #if A_USE_TESSELLATION_MIN_EDGE_LENGTH
        edgeLength = max(_MinEdgeLength, edgeLength);
    #endif
      
        tf = UnityEdgeLengthBasedTessCull(vi[0].vertex, v[1].vertex, v[2].vertex, edgeLength, maxDisplacement);

        o.edge[0] = tf.x; 
        o.edge[1] = tf.y; 
        o.edge[2] = tf.z; 
        o.inside = tf.w;
        return o;
    }

    AVertexToTessellation aVertexTessellationShader(
        AVertex v) 
    {
        AVertexToTessellation o;
        UNITY_INITIALIZE_OUTPUT(AVertexToTessellation, o);
        o.vertex = v.vertex;
        o.normal = v.normal;
        o.uv0 = v.uv0;
        o.uv1 = v.uv1;
      
    #ifdef A_UV2_ON
        o.uv2 = v.uv2;
    #endif
    #ifdef A_TANGENT_TO_WORLD_ON
        o.tangent = v.tangent;
    #endif
        o.color = v.color;

        return o;
    }

    // tessellation hull shader
    [UNITY_domain("tri")]
    [UNITY_partitioning("fractional_odd")]
    [UNITY_outputtopology("triangle_cw")]
    [UNITY_patchconstantfunc("aHullConstantTessellation")]
    [UNITY_outputcontrolpoints(3)]
    AVertexToTessellation aHullShader(
        InputPatch<AVertexToTessellation, 3> v, 
        uint id : SV_OutputControlPointID) 
    {
        return v[id];
    }

    [UNITY_domain("tri")]
    void aDomainShader(
        UnityTessellationFactors tessFactors,
        const OutputPatch<AVertexToTessellation, 3> vi,
        float3 bary : SV_DomainLocation,
    #ifndef A_VERTEX_TO_FRAGMENT_OFF
        out AVertexToFragment o,
    #endif
        out float4 opos : SV_POSITION)
    {
        AVertex v;
        UNITY_INITIALIZE_OUTPUT(AVertex, v);

        v.vertex = vi[0].vertex * bary.x + vi[1].vertex * bary.y + vi[2].vertex * bary.z;
        v.normal = vi[0].normal * bary.x + vi[1].normal * bary.y + vi[2].normal * bary.z;
        v.uv0 = vi[0].uv0 * bary.x + vi[1].uv0 * bary.y + vi[2].uv0 * bary.z;
        v.uv1 = vi[0].uv1 * bary.x + vi[1].uv1 * bary.y + vi[2].uv1 * bary.z;	 

    #ifdef A_UV2_ON
        v.uv2 = vi[0].uv2 * bary.x + vi[1].uv2 * bary.y + vi[2].uv2 * bary.z;	  
    #endif
    #ifdef A_TANGENT_TO_WORLD_ON
        v.tangent = vi[0].tangent * bary.x + vi[1].tangent * bary.y + vi[2].tangent * bary.z;
    #endif
        v.color = vi[0].color * bary.x + vi[1].color * bary.y + vi[2].color * bary.z;

    #ifdef _TESSELLATIONMODE_PHONG
        float3 pp[3];
        
        for (int i = 0; i < 3; ++i)
            pp[i] = v.vertex.xyz - vi[i].normal * (dot(v.vertex.xyz, vi[i].normal) - dot(vi[i].vertex.xyz, vi[i].normal));
        
        float3 displacedPosition = pp[0] * bary.x + pp[1] * bary.y + pp[2] * bary.z;
        v.vertex.xyz = lerp(v.vertex.xyz, displacedPosition, _Phong);
    #endif

    #ifdef _VERTEXWRAP_ON
        float4 objCoord = v.vertex;
        float4 camCoord = mul(UNITY_MATRIX_MVP, objCoord);
        float4 scrCoord = ComputeScreenPos(objCoord);
        float2 scrUv = scrCoord.xy / scrCoord.w;

        float vtxDepth = -mul(UNITY_MATRIX_MV, objCoord).z;
        float refDepth = LinearEyeDepth(tex2Dlod(_CameraDepthTexture, float4(scrUv, 0.0f, 0.0f)).r);

        float offset = 0.0f;

        for (int iter = 1; iter < 32; iter ++)
        {
            float rayDist = 0.0002f * iter;

            objCoord.z = v.vertex.z - rayDist;
            camCoord = mul(UNITY_MATRIX_MVP, objCoord);
            scrCoord = ComputeScreenPos(camCoord);
            scrUv = scrCoord.xy / scrCoord.w;

            vtxDepth = -mul(UNITY_MATRIX_MV, objCoord).z;
            float refDepth = LinearEyeDepth(tex2Dlod(_CameraDepthTexture, float4(scrUv, 0.0f, 0.0f)).r);

            offset = refDepth > vtxDepth ? rayDist : offset;
        }

        v.vertex.z -= offset * 0.9f;
    #endif
    
    // NOTE: This has to come second, since the Phong mode references the 
    // unmodified vertices in order to work!
    #ifdef _TESSELLATIONMODE_DISPLACEMENT
        float d = 0.01f * _Displacement;
        float oscillation = _Time.y;
        float2 tessUv = TRANSFORM_TEX(v.uv0.xy, _DispTex) + (_DispTexVelocity * oscillation);
        
        #ifdef _DISPALPHA_ON
            d *= pow(tex2Dlod(_MainTex, float4(tessUv, 0.0f, 0.0f)).a, 4);
        #else
            d *= tex2Dlod(_DispTex, float4(tessUv, 0.0f, 0.0f)).g;
        #endif
        
        v.vertex.xyz += v.normal * d;
    #endif

        aVertexShader(
            v, 
    #ifndef A_VERTEX_TO_FRAGMENT_OFF
            o, 
    #endif
            opos);
    }
#endif

#endif // A_FRAMEWORK_TESSELLATION_CGINC
