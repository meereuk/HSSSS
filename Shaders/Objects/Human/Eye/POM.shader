Shader "HSSSS/Human/Eye/POM"
{
    Properties
    {
        [Header(Albedo)]
        _MainTex ("IrisTex", 2D) = "white" {}
        _Color ("IrisColor", Color) = (1,1,1,1)

        _ScleraBaseMap ("ScleraBaseMap", 2D) = "white" {}
        _ScleraVeinMap ("ScleraVeinMap", 2D) = "white" {}
        _VeinScale ("VeinScale", Range(0, 1)) = 0
        _SpecColor ("ScleraColor", Color) = (1,1,1,1)

        [Header(Parallax)]
        _HeightMap("HeightMap", 2D) = "white" {}

        _Parallax ("Parallax", Range(0, 0.08)) = 0
        _PupilSize ("PupilSize", Range(0, 1.0)) = 0
    
        [Header(Specular)]
        _Metallic ("Metallic", Range(0, 1)) = 0
        _Smoothness ("Smoothness", Range(0, 1)) = 0

        [Header(Normal)]
        _BumpMap("BumpMap", 2D) = "bump" {}
        _BumpScale("BumpScale", Float) = 1

        [Header(DetailNormal)]
        [Toggle] _DETAILNORMAL ("Toggle DetailNormal", Float) = 0
        _DetailNormalMap("DetailNormalMap", 2D) = "bump" {}
        _DetailNormalMapScale("DetailNormalMapScale", Float) = 1

        [Header(Emission)]
        [Toggle] _EMISSION ("Toggle Emission", Float) = 0
        _EmissionMap ("EmissionMap", 2D) = "white" {}
        _EmissionColor ("EmissionColor", Color) = (0, 0, 0, 1)
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Geometry" 
            "RenderType" = "Opaque"
        }

        LOD 400

        Pass
        {
            Name "FORWARD" 
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM
            #pragma target 5.0
            #pragma exclude_renderers gles
        
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            
            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_FORWARDBASE
        
            #include "Assets/HSSSS/Definitions/Eyeball.cginc"
            #include "Assets/HSSSS/Passes/ForwardBase.cginc"
            ENDCG
        }
    
        Pass
        {
            Name "FORWARD_DELTA"
            Tags { "LightMode" = "ForwardAdd" }
        
            Blend One One
            ZWrite Off

            CGPROGRAM
            #pragma target 5.0
            #pragma exclude_renderers gles
        
            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog

            #pragma shader_feature ___ _DETAILNORMAL_ON
            #pragma shader_feature ___ _EMISSION_ON
        
            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader

            #define UNITY_PASS_FORWARDADD

            #include "Assets/HSSSS/Definitions/Eyeball.cginc"
            #include "Assets/HSSSS/Passes/ForwardAdd.cginc"
            ENDCG
        }
    
        Pass
        {
            Name "SHADOWCASTER"
            Tags { "LightMode" = "ShadowCaster" }
        
            CGPROGRAM
            #pragma target 5.0
            #pragma exclude_renderers gles
        
            #pragma multi_compile_shadowcaster

            #pragma shader_feature ___ _DETAILNORMAL_ON
            #pragma shader_feature ___ _EMISSION_ON

            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_SHADOWCASTER
        
            #include "Assets/HSSSS/Definitions/Eyeball.cginc"
            #include "Assets/HSSSS/Passes/Shadow.cginc"
            ENDCG
        }
    
        Pass
        {
            Name "DEFERRED"
            Tags { "LightMode" = "Deferred" }

            CGPROGRAM
            #pragma target 5.0
            #pragma exclude_renderers nomrt gles
        
            #pragma multi_compile ___ UNITY_HDR_ON
            #pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
            #pragma multi_compile DIRLIGHTMAP_OFF DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE
            #pragma multi_compile DYNAMICLIGHTMAP_OFF DYNAMICLIGHTMAP_ON

            #pragma shader_feature ___ _DETAILNORMAL_ON
            #pragma shader_feature ___ _EMISSION_ON
        
            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_DEFERRED
        
            #include "Assets/HSSSS/Definitions/Eyeball.cginc"
            #include "Assets/HSSSS/Passes/Deferred.cginc"
            ENDCG
        }
    
        Pass
        {
            Name "Meta"
            Tags { "LightMode" = "Meta" }
            Cull Off

            CGPROGRAM
            #pragma target 5.0
            #pragma exclude_renderers nomrt gles

            #pragma shader_feature ___ _EMISSION_ON
                
            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_META
        
            #include "Assets/HSSSS/Definitions/Eyeball.cginc"
            #include "Assets/HSSSS/Passes/Meta.cginc"
            ENDCG
        }
    }

    FallBack "Standard"
}
