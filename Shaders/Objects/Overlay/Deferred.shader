Shader "HSSSS/Overlay/Deferred"
{
    Properties
    {
        [Enum(Standard, 0, Anisotropic, 1, Sheen, 2, Skin, 3)]
        _MaterialType("Material Type",Float) = 0
           
        [Space(8)][Header(Albedo)]
        _MainTex ("Main Texture", 2D) = "white" {}
        _Color ("Main Color", Color) = (1,1,1,1)

        [Space(8)][Header(Emission)]
        _EmissionMap ("Emission Map", 2D) = "white" {}
        _EmissionColor ("Emission Color", Color) = (0, 0, 0, 1)

        [Space(8)][Header(Specular)]
        _SpecGlossMap ("SpecGlossMap", 2D) = "white" {}
        _SpecColor ("SpecColor", Color) = (1,1,1,1)
        _Metallic ("Specularity", Range(0, 1)) = 0
        _Smoothness ("Smoothness", Range(0, 1)) = 0

        [Space(8)][Header(Occlusion)]
        _OcclusionMap ("OcclusionMap", 2D) = "white" {}
        _OcclusionStrength ("OcclusionStrength", Range(0, 1)) = 0

        [Space(8)][Header(Normal)]
        _BumpMap ("BumpMap", 2D) = "bump" {}
        _BumpScale ("BumpScale", Float) = 1

        [Space(8)][Header(Anisotropy)]
        _Anisotropy ("Anisotropy", Range(-1, 1)) = 0

        [Space(8)][Header(Transparency)]
        _FresnelAlpha ("Fresnel Alpha", Range(0, 1)) = 0
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
            #pragma target 5.0
            #pragma only_renderers d3d11

            #pragma multi_compile ___ UNITY_HDR_ON
            #pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
            #pragma multi_compile DIRLIGHTMAP_OFF DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE
            #pragma multi_compile DYNAMICLIGHTMAP_OFF DYNAMICLIGHTMAP_ON
        
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
            #pragma target 5.0
            #pragma only_renderers d3d11
                
            #pragma multi_compile ___ UNITY_HDR_ON
            #pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
            #pragma multi_compile DIRLIGHTMAP_OFF DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE
            #pragma multi_compile DYNAMICLIGHTMAP_OFF DYNAMICLIGHTMAP_ON
        
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