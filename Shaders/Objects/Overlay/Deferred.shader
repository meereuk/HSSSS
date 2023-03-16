Shader "HSSSS/Overlay/Deferred"
{
    Properties
    {
        [HideinInspector][Enum(UnityEngine.Rendering.CullMode)] _Cull ("Culling Mode", Float) = 2

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

    CGINCLUDE
        #define A_FINAL_GBUFFER_ON
    ENDCG

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
        Offset -1, -1

        UsePass "HSSSS/Overlay/Forward/FORWARD"
        UsePass "HSSSS/Overlay/Forward/FORWARD_DELTA"
    
        Pass
        {
            Name "DEFERRED"
            Tags { "LightMode" = "Deferred" }

            // Only overwrite G-Buffer RGB, but weight whole G-Buffer.
            Blend SrcAlpha OneMinusSrcAlpha, Zero OneMinusSrcAlpha
            ZWrite Off
            Cull Back

            CGPROGRAM
            #pragma target 3.0
            #pragma exclude_renderers nomrt gles

            #pragma multi_compile ___ UNITY_HDR_ON
            #pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
            #pragma multi_compile DIRLIGHTMAP_OFF DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE
            #pragma multi_compile DYNAMICLIGHTMAP_OFF DYNAMICLIGHTMAP_ON

            #pragma shader_feature _MATERIALTYPE_COMMON _MATERIALTYPE_CLOTH _MATERIALTYPE_SKIN
            #pragma shader_feature _WORKFLOW_METALLIC _WORKFLOW_SPECULAR

            #pragma shader_feature ___ _DETAILALBEDO_ON
            #pragma shader_feature ___ _COLORMASK_ON
            #pragma shader_feature ___ _EMISSION_ON
            #pragma shader_feature ___ _SPECGLOSS_ON
            #pragma shader_feature ___ _OCCLUSION_ON
            #pragma shader_feature ___ _BLENDNORMAL_ON
            #pragma shader_feature ___ _DETAILNORMAL_ON
            #pragma shader_feature ___ _TRANSMISSION_ON
        
            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_DEFERRED
            #define A_DECAL_ALPHA_FIRSTPASS
        
            #include "Assets/HSSSS/Definitions/Core.cginc"
            #include "Assets/HSSSS/Passes/Deferred.cginc"
            ENDCG
        }
    
        Pass
        {
            Name "DEFERRED"
            Tags { "LightMode" = "Deferred" }

            // Only overwrite GBuffer A.
            Blend One One
            ColorMask A
            ZWrite Off
            Cull Back

            CGPROGRAM
            #pragma target 3.0
            #pragma exclude_renderers nomrt gles
                
            #pragma multi_compile ___ UNITY_HDR_ON
            #pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
            #pragma multi_compile DIRLIGHTMAP_OFF DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE
            #pragma multi_compile DYNAMICLIGHTMAP_OFF DYNAMICLIGHTMAP_ON

            #pragma shader_feature _MATERIALTYPE_COMMON _MATERIALTYPE_CLOTH _MATERIALTYPE_SKIN
            #pragma shader_feature _WORKFLOW_METALLIC _WORKFLOW_SPECULAR

            #pragma shader_feature ___ _DETAILALBEDO_ON
            #pragma shader_feature ___ _COLORMASK_ON
            #pragma shader_feature ___ _EMISSION_ON
            #pragma shader_feature ___ _SPECGLOSS_ON
            #pragma shader_feature ___ _OCCLUSION_ON
            #pragma shader_feature ___ _BLENDNORMAL_ON
            #pragma shader_feature ___ _DETAILNORMAL_ON
            #pragma shader_feature ___ _TRANSMISSION_ON
        
            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_DEFERRED
        
            #include "Assets/HSSSS/Definitions/Core.cginc"
            #include "Assets/HSSSS/Passes/Deferred.cginc"
            ENDCG
        }
    } 

    FallBack Off
}