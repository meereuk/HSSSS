Shader "HSSSS/Overlay/Deferred"
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
    }

    SubShader
    {
        Tags
        {
            "Queue" = "AlphaTest" 
            "IgnoreProjector" = "True" 
            "RenderType" = "Opaque" 
            "ForceNoShadowCasting" = "True"
        }
        LOD 300
        Offset -1,-1

        Pass
        {
            Name "FORWARD" 
            Tags { "LightMode" = "ForwardBase" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Back

            CGPROGRAM
            #pragma target 3.0
            #pragma exclude_renderers gles
        
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
        
            #pragma multi_compile ___ _METALLIC_OFF
            
            #pragma shader_feature ___ _DETAILALBEDO_ON
            #pragma shader_feature ___ _COLORMASK_ON
            #pragma shader_feature ___ _BLENDNORMAL_ON
            #pragma shader_feature ___ _DETAILNORMAL_ON
            #pragma shader_feature ___ _EMISSION_ON

            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_FORWARDBASE
            #define _ALPHABLEND_ON
        
            #include "Assets/HSSSS/Definitions/Overlay.cginc"
            #include "Assets/HSSSS/Passes/ForwardBase.cginc"
            ENDCG
        }
    
        Pass
        {
            Name "FORWARD_DELTA"
            Tags { "LightMode" = "ForwardAdd" }
        
            Blend SrcAlpha One
            ZWrite Off
            Cull Back

            CGPROGRAM
            #pragma target 3.0
            #pragma exclude_renderers gles
        
            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog

            #pragma multi_compile ___ _METALLIC_OFF

            #pragma shader_feature ___ _DETAILALBEDO_ON
            #pragma shader_feature ___ _COLORMASK_ON
            #pragma shader_feature ___ _BLENDNORMAL_ON
            #pragma shader_feature ___ _DETAILNORMAL_ON
            #pragma shader_feature ___ _EMISSION_ON
        
            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader

            #define UNITY_PASS_FORWARDADD
            #define _ALPHABLEND_ON
        
            #include "Assets/HSSSS/Definitions/Overlay.cginc"
            #include "Assets/HSSSS/Passes/ForwardAdd.cginc"
            ENDCG
        }
    
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

            #pragma multi_compile ___ _SKINEFFECT_ON
            #pragma multi_compile ___ _METALLIC_OFF
            
            #pragma shader_feature ___ _DETAILALBEDO_ON
            #pragma shader_feature ___ _COLORMASK_ON
            #pragma shader_feature ___ _BLENDNORMAL_ON
            #pragma shader_feature ___ _DETAILNORMAL_ON
            #pragma shader_feature ___ _EMISSION_ON
        
            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_DEFERRED
            #define A_DECAL_ALPHA_FIRSTPASS
        
            #include "Assets/HSSSS/Definitions/Overlay.cginc"
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

            #pragma multi_compile ___ _SKINEFFECT_ON
            #pragma multi_compile ___ _METALLIC_OFF

            #pragma shader_feature ___ _DETAILALBEDO_ON
            #pragma shader_feature ___ _COLORMASK_ON
            #pragma shader_feature ___ _BLENDNORMAL_ON
            #pragma shader_feature ___ _DETAILNORMAL_ON
            #pragma shader_feature ___ _EMISSION_ON
        
            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_DEFERRED
        
            #include "Assets/HSSSS/Definitions/Overlay.cginc"
            #include "Assets/HSSSS/Passes/Deferred.cginc"
            ENDCG
        }
    } 

    FallBack Off
}