Shader "HSSSS/Human/Hair/Deferred"
{
    Properties
    {
        [Header(MaterialType)]
        [KeywordEnum(Metallic, Specular)] _Workflow ("Specular Workflow", Float) = 0

        [Space(8)][Header(Albedo)]
        _MainTex ("Main Texture", 2D) = "white" {}
        _Color ("Primary Color", Color) = (1,1,1,1)

        [Space(8)][Header(DetailAlbedo)]
        [Toggle] _DETAILALBEDO ("Toggle DetailAlbedo", Float) = 0
        _DetailAlbedoMap ("Detail Albedo", 2D) = "white" {}

        [Space(8)][Header(Emission)]
        [Toggle] _EMISSION ("Toggle Emission", Float) = 0
        _EmissionMap ("EmissionMap", 2D) = "white" {}
        _EmissionColor ("EmissionColor", Color) = (0, 0, 0, 1)

        [Space(8)][Header(Specular)]
        [Toggle] _SPECGLOSS ("Toggle", Float) = 0
        _SpecGlossMap ("Glossiness Map", 2D) = "white" {}
        _SpecColor ("Specular Color", Color) = (1,1,1,1)
        _Smoothness ("Smoothness", Range(0, 1)) = 0

        [Space(8)][Header(Occlusion)]
        [Toggle] _Occlusion ("Toggle", Float) = 0
        _OcclusionMap ("OcclusionMap", 2D) = "white" {}
        _OcclusionStrength ("OcclusionStrength", Range(0, 1)) = 0

        [Space(8)][Header(Normal)]
        _BumpMap ("BumpMap", 2D) = "bump" {}
        _BumpScale ("BumpScale", Float) = 1

        [Space(8)][Header(Transparency)]
        _Metallic ("Hash", Range(0, 1)) = 0
        _Cutoff ("Cutoff", Range(0, 1)) = 0.5
        _FuzzBias ("FuzzBias", Range(0, 1)) = 0.0
        _BlueNoise ("Blue Noise", 2D) = "black" {}
    }


    SubShader
    {
        Tags
        {
            "Queue" = "AlphaTest"
            "RenderType" = "TransparentCutout"
        }

        LOD 300

        Pass
        {
            Name "FORWARD" 
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM
            #pragma target 3.0
            #pragma exclude_renderers gles
        
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog

            #pragma shader_feature _WORKFLOW_METALLIC _WORKFLOW_SPECULAR

            #pragma shader_feature ___ _DETAILALBEDO_ON
            #pragma shader_feature ___ _EMISSION_ON
            #pragma shader_feature ___ _SPECGLOSS_ON
            #pragma shader_feature ___ _OCCLUSION_ON

            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_FORWARDBASE
            #define _ALPHAHASHED_ON
        
            #include "Assets/HSSSS/Definitions/Core.cginc"
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
            #pragma target 3.0
            #pragma exclude_renderers gles
        
            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog

            #pragma shader_feature _WORKFLOW_METALLIC _WORKFLOW_SPECULAR

            #pragma shader_feature ___ _DETAILALBEDO_ON
            #pragma shader_feature ___ _EMISSION_ON
            #pragma shader_feature ___ _SPECGLOSS_ON
            #pragma shader_feature ___ _OCCLUSION_ON
        
            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader

            #define UNITY_PASS_FORWARDADD
            #define _ALPHAHASHED_ON

            #include "Assets/HSSSS/Definitions/Core.cginc"
            #include "Assets/HSSSS/Passes/ForwardAdd.cginc"
            ENDCG
        }
    
        Pass
        {
            Name "SHADOWCASTER"
            Tags { "LightMode" = "ShadowCaster" }
        
            CGPROGRAM
            #pragma target 3.0
            #pragma exclude_renderers gles
        
            #pragma multi_compile_shadowcaster

            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_SHADOWCASTER
        
            #include "Assets/HSSSS/Definitions/Core.cginc"
            #include "Assets/HSSSS/Passes/Shadow.cginc"
            ENDCG
        }

        Pass
        {
            Name "DEFERRED"
            Tags { "LightMode" = "Deferred" }

            CGPROGRAM
            #pragma target 3.0
            #pragma exclude_renderers nomrt gles

            #pragma multi_compile ___ UNITY_HDR_ON
            #pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
            #pragma multi_compile DIRLIGHTMAP_OFF DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE
            #pragma multi_compile DYNAMICLIGHTMAP_OFF DYNAMICLIGHTMAP_ON

            #pragma shader_feature _WORKFLOW_METALLIC _WORKFLOW_SPECULAR

            #pragma shader_feature ___ _DETAILALBEDO_ON
            #pragma shader_feature ___ _EMISSION_ON
            #pragma shader_feature ___ _SPECGLOSS_ON
            #pragma shader_feature ___ _OCCLUSION_ON

            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader

            #define UNITY_PASS_DEFERRED
            #define _ALPHAHASHED_ON

            #include "Assets/HSSSS/Definitions/Core.cginc"
            #include "Assets/HSSSS/Passes/Deferred.cginc"
            ENDCG
        }
    }

    FallBack "VertexLit"
}
