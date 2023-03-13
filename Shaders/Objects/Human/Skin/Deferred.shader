Shader "HSSSS/Human/Skin/Deferred"
{
    Properties
    {
        [Header(Albedo)]
        _MainTex ("Main Texture", 2D) = "white" {}
        _Color ("Main Color", Color) = (1,1,1,1)

        [Toggle] _DETAILALBEDO ("Toggle DetailAlbedo", Float) = 0
        _DetailAlbedoMap ("Detail Albedo", 2D) = "white" {}

        [Toggle] _COLORMASK ("Toggle ColorMask", Float) = 0
        _ColorMask ("Color Mask", 2D) = "black" {}
        _Color_3 ("Secondary Color", Color) = (1,1,1,1)

        [Header(Emission)]
        [Toggle] _EMISSION ("Toggle Emission", Float) = 0
        _EmissionMap ("EmissionMap", 2D) = "white" {}
        _EmissionColor ("EmissionColor", Color) = (0, 0, 0, 1)

        [Header(Specular)]
        _SpecGlossMap ("SpecGlossMap", 2D) = "white" {}
        _SpecColor ("SpecColor", Color) = (1,1,1,1)
        _Metallic ("Specularity", Range(0, 1)) = 0
        _Smoothness ("Smoothness", Range(0, 1)) = 0

        [Header(Occlusion)]
        _OcclusionMap ("OcclusionMap", 2D) = "white" {}
        _OcclusionStrength ("OcclusionStrength", Range(0, 1)) = 0

        [Header(Normal)]
        _BumpMap ("BumpMap", 2D) = "bump" {}
        _BumpScale ("BumpScale", Float) = 1

        [Header(BlendNormal)]
        [Toggle] _BLENDNORMAL ("Toggle BlendNormal", Float) = 0
        _BlendNormalMap ("BlendNormalMap", 2D) = "bump" {}
        _BlendNormalMapScale("BlendNormalMapScale", Float) = 1

        [Header(DetailNormal)]
        [Toggle] _DETAILNORMAL ("Toggle DetailNormal", Float) = 0
        _DetailNormalMap ("DetailNormalMap", 2D) = "bump" {}
        _DetailNormalMapScale ("DetailNormalMapScale", Float) = 1

        [Header(MicroDetails)]
        [Toggle] _MICRODETAILS ("Toggle Microdetails", Float) = 0
        _DetailNormalMap_2 ("DetailNormalMap_2", 2D) = "bump" {}
        _DetailNormalMapScale_2 ("DetailNormalMapScale_2", Float) = 1
        _DetailNormalMap_3 ("DetailNormalMap_3", 2D) = "bump" {}
        _DetailNormalMapScale_3 ("DetailNormalMapScale_3", Float) = 1
        _DetailSkinPoreMap ("DetailSkinPoreMap", 2D) = "white" {}

        [Header(Thickness)]
        _Thickness ("ThicknessMap", 2D) = "white" {}
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
            #pragma target 3.0
            #pragma exclude_renderers gles

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            
            #pragma multi_compile ___ _MICRODETAILS_ON
            #pragma multi_compile ___ _WET_SPECGLOSS

            #pragma shader_feature ___ _EMISSION_ON
            #pragma shader_feature ___ _DETAILALBEDO_ON
            #pragma shader_feature ___ _COLORMASK_ON
            #pragma shader_feature ___ _BLENDNORMAL_ON
            #pragma shader_feature ___ _DETAILNORMAL_ON

            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader

            #define UNITY_PASS_FORWARDBASE

            #include "Assets/HSSSS/Definitions/Skin.cginc"
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

            #pragma multi_compile ___ _MICRODETAILS_ON
            #pragma multi_compile ___ _WET_SPECGLOSS

            #pragma shader_feature ___ _EMISSION_ON
            #pragma shader_feature ___ _DETAILALBEDO_ON
            #pragma shader_feature ___ _COLORMASK_ON
            #pragma shader_feature ___ _BLENDNORMAL_ON
            #pragma shader_feature ___ _DETAILNORMAL_ON

            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader

            #define UNITY_PASS_FORWARDADD

            #include "Assets/HSSSS/Definitions/Skin.cginc"
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
        
            #include "Assets/HSSSS/Definitions/Skin.cginc"
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

            #pragma multi_compile ___ _MICRODETAILS_ON
            #pragma multi_compile ___ _WET_SPECGLOSS

            #pragma shader_feature ___ _EMISSION_ON
            #pragma shader_feature ___ _DETAILALBEDO_ON
            #pragma shader_feature ___ _COLORMASK_ON
            #pragma shader_feature ___ _BLENDNORMAL_ON
            #pragma shader_feature ___ _DETAILNORMAL_ON

            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader

            #define UNITY_PASS_DEFERRED

            #include "Assets/HSSSS/Definitions/Skin.cginc"
            #include "Assets/HSSSS/Passes/Deferred.cginc"
            ENDCG
        }
    
        Pass
        {
            Name "Meta"
            Tags { "LightMode" = "Meta" }
            Cull Off
            
            CGPROGRAM
            #pragma target 3.0
            #pragma exclude_renderers nomrt gles

            #pragma shader_feature ___ _EMISSION_ON
            #pragma shader_feature ___ _DETAILALBEDO_ON
            #pragma shader_feature ___ _COLORMASK_ON

            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader

            #define UNITY_PASS_META

            #include "Assets/HSSSS/Definitions/Skin.cginc"
            #include "Assets/HSSSS/Passes/Meta.cginc"
            ENDCG
        }
    }

    FallBack "Standard"
}