Shader "HSSSS/Overlay/Tessellation/Forward"
{
    Properties
    {
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Culling Mode", Float) = 0

        [Toggle] _VERTEXWRAP ("Toggle Vertex Wrapping", Float) = 0
        [Toggle] _DISPALPHA ("Toggle Alpha Displacement", Float) = 0

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

        [Header(Tessellation)]
        _DispTex ("HeightMap", 2D) = "black" {}
        _Displacement ("Displacement", Range(0, 30)) = 0.1
        _Phong ("PhongStrength", Range(0, 1)) = 0.5
        _EdgeLength ("EdgeLength", Range(2, 50)) = 2
    }

    CGINCLUDE
        #define A_TESSELLATION_ON
    ENDCG

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent" 
            "IgnoreProjector" = "True" 
            "RenderType" = "Transparent"
            "PerformanceChecks" = "False"
            "ForceNoShadowCasting" = "True"
        }

        LOD 400

        Pass
        {
            Name "FORWARD" 
            Tags { "LightMode" = "ForwardBase" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull [_Cull]

            CGPROGRAM
            #pragma target gl4.1
            #pragma exclude_renderers gles

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog

            #pragma multi_compile ___ _METALLIC_OFF

            #pragma shader_feature ___ _VERTEXWRAP_ON
            #pragma shader_feature ___ _DISPALPHA_ON
            #pragma shader_feature ___ _DETAILALBEDO_ON
            #pragma shader_feature ___ _COLORMASK_ON
            #pragma shader_feature ___ _BLENDNORMAL_ON
            #pragma shader_feature ___ _DETAILNORMAL_ON
            #pragma shader_feature ___ _EMISSION_ON
            
            #pragma hull aHullShader
            #pragma vertex aVertexTessellationShader
            #pragma domain aDomainShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_FORWARDBASE
            #define _TESSELLATIONMODE_COMBINED
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
            #pragma target gl4.1
            #pragma exclude_renderers gles
        
            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog

            #pragma multi_compile ___ _METALLIC_OFF
            
            #pragma shader_feature ___ _VERTEXWRAP_ON
            #pragma shader_feature ___ _DISPALPHA_ON
            #pragma shader_feature ___ _DETAILALBEDO_ON
            #pragma shader_feature ___ _COLORMASK_ON
            #pragma shader_feature ___ _BLENDNORMAL_ON
            #pragma shader_feature ___ _DETAILNORMAL_ON
            #pragma shader_feature ___ _EMISSION_ON
        
            #pragma hull aHullShader
            #pragma vertex aVertexTessellationShader
            #pragma domain aDomainShader
            #pragma fragment aFragmentShader

            #define UNITY_PASS_FORWARDADD
            #define _TESSELLATIONMODE_COMBINED
            #define _ALPHABLEND_ON

            #include "Assets/HSSSS/Definitions/Core.cginc"
            #include "Assets/HSSSS/Passes/ForwardAdd.cginc"
            ENDCG
        }
    }

    FallBack "VertexLit"
}