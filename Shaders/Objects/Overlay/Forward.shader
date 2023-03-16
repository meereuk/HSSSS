Shader "HSSSS/Overlay/Forward"
{
    Properties
    {
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Culling Mode", Float) = 2

        [Header(MaterialType)]
        [KeywordEnum(Common, Cloth, Skin)] _MaterialType ("Material Type", Float) = 0
        [KeywordEnum(Metallic, Specular)] _Workflow ("Specular Workflow", Float) = 0

        [Space(8)][Header(Albedo)]
        _MainTex ("Main Texture", 2D) = "white" {}
        _Color ("Main Color", Color) = (1,1,1,1)

        [Space(8)][Header(DetailAlbedo)]
        [Toggle] _DETAILALBEDO ("Toggle", Float) = 0
        _DetailAlbedoMap ("Detail Albedo", 2D) = "white" {}

        [Space(8)][Header(ColorMask)]
        [Toggle] _COLORMASK ("Toggle", Float) = 0
        _ColorMask ("Color Mask", 2D) = "black" {}
        _Color_3 ("Secondary Color", Color) = (1,1,1,1)

        [Space(8)][Header(Emission)]
        [Toggle] _EMISSION ("Toggle", Float) = 0
        _EmissionMap ("Emission Map", 2D) = "white" {}
        _EmissionColor ("Emission Color", Color) = (0, 0, 0, 1)

        [Space(8)][Header(Specular)]
        [Toggle] _SPECGLOSS ("Toggle", Float) = 0
        _SpecGlossMap ("SpecGlossMap", 2D) = "white" {}
        _SpecColor ("SpecColor", Color) = (1,1,1,1)
        _Metallic ("Specularity", Range(0, 1)) = 0
        _Smoothness ("Smoothness", Range(0, 1)) = 0

        [Space(8)][Header(Occlusion)]
        [Toggle] _Occlusion ("Toggle", Float) = 0
        _OcclusionMap ("OcclusionMap", 2D) = "white" {}
        _OcclusionStrength ("OcclusionStrength", Range(0, 1)) = 0

        [Space(8)][Header(Normal)]
        _BumpMap ("BumpMap", 2D) = "bump" {}
        _BumpScale ("BumpScale", Float) = 1

        [Space(8)][Header(BlendNormal)]
        [Toggle] _BLENDNORMAL ("Toggle", Float) = 0
        _BlendNormalMap ("BlendNormalMap", 2D) = "bump" {}
        _BlendNormalMapScale("BlendNormalMapScale", Float) = 1

        [Space(8)][Header(DetailNormal)]
        [Toggle] _DETAILNORMAL ("Toggle", Float) = 0
        _DetailNormalMap ("DetailNormalMap", 2D) = "bump" {}
        _DetailNormalMapScale ("DetailNormalMapScale", Float) = 1

        [Space(8)][Header(Transmission)]
        [Toggle] _TRANSMISSION ("Toggle", Float) = 0
        _Thickness ("ThicknessMap", 2D) = "white" {}
    }

    SubShader
    {
        Tags
        {
            "Queue" = "AlphaTest"
            "RenderType" = "Opaque"
            "IgnoreProjector" = "True"
            "ForceNoShadowCasting" = "True"
        }

        LOD 300

        Pass
        {
            Name "FORWARD" 
            Tags { "LightMode" = "ForwardBase" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull [_Cull]

            CGPROGRAM
            #pragma target 3.0
            #pragma exclude_renderers gles

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog

            #pragma shader_feature _WORKFLOW_METALLIC _WORKFLOW_SPECULAR

            #pragma shader_feature ___ _DETAILALBEDO_ON
            #pragma shader_feature ___ _COLORMASK_ON
            #pragma shader_feature ___ _EMISSION_ON
            #pragma shader_feature ___ _SPECGLOSS_ON
            #pragma shader_feature ___ _OCCLUSION_ON
            #pragma shader_feature ___ _BLENDNORMAL_ON
            #pragma shader_feature ___ _DETAILNORMAL_ON
            
            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_FORWARDBASE
            #define _ALPHABLEND_ON
        
            #include "Assets/HSSSS/Definitions/Core.cginc"
            #include "Assets/HSSSS/Passes/ForwardBase.cginc"
            ENDCG
        }
    
        Pass
        {
            Name "FORWARD_DELTA"
            Tags { "LightMode" = "ForwardAdd" }
        
            Blend SrcAlpha One
            ZWrite Off
            Cull [_Cull]

            CGPROGRAM
            #pragma target 3.0
            #pragma exclude_renderers gles
        
            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog

            #pragma shader_feature _WORKFLOW_METALLIC _WORKFLOW_SPECULAR

            #pragma shader_feature ___ _DETAILALBEDO_ON
            #pragma shader_feature ___ _COLORMASK_ON
            #pragma shader_feature ___ _EMISSION_ON
            #pragma shader_feature ___ _SPECGLOSS_ON
            #pragma shader_feature ___ _OCCLUSION_ON
            #pragma shader_feature ___ _BLENDNORMAL_ON
            #pragma shader_feature ___ _DETAILNORMAL_ON
        
            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader

            #define UNITY_PASS_FORWARDADD
            #define _ALPHABLEND_ON

            #include "Assets/HSSSS/Definitions/Core.cginc"
            #include "Assets/HSSSS/Passes/ForwardAdd.cginc"
            ENDCG
        }
    }

    FallBack "Standard"
}