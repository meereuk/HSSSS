Shader "HSSSS/Overlay/Tessellation/Hash"
{
    Properties
    {
        [Enum(Standard, 0, Null, 1, Cloth, 2, Skin, 3)]
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

        [Space(8)][Header(Tessellation)]
        _DispTex ("HeightMap", 2D) = "black" {}
        _Displacement ("Displacement", Range(0, 30)) = 0.1
        _Phong ("PhongStrength", Range(0, 1)) = 0.5
        _EdgeLength ("EdgeLength", Range(2, 50)) = 2

        [Space(8)][Header(Transparency)]
        _Hash ("Hash", Range(0, 1)) = 0
        _FuzzBias ("FuzzBias", Range(0, 1)) = 0.0
        _BlueNoise ("Blue Noise", 2D) = "black" {}
        _FresnelAlpha ("Fresnel Alpha", Range(0, 1)) = 0
    }

    CGINCLUDE
        #define A_TESSELLATION_ON
        #define _TESSELLATIONMODE_COMBINED
    ENDCG

    SubShader
    {
        Tags
        {
            "Queue" = "AlphaTest" 
            "RenderType" = "TransparentCutout"
        }
        LOD 400

        Pass
        {
            Name "FORWARD" 
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM
            #pragma target 5.0
            #pragma only_renderers d3d11
        
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog

            #pragma hull aHullShader
            #pragma vertex aVertexTessellationShader
            #pragma domain aDomainShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_FORWARDBASE
            #define _ALPHAHASHED_ON
        
            #include "Assets/HSSSS/Definitions/Overlay.cginc"
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
            #pragma only_renderers d3d11
        
            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog

            #pragma hull aHullShader
            #pragma vertex aVertexTessellationShader
            #pragma domain aDomainShader
            #pragma fragment aFragmentShader

            #define UNITY_PASS_FORWARDADD
            #define _ALPHAHASHED_ON

            #include "Assets/HSSSS/Definitions/Overlay.cginc"
            #include "Assets/HSSSS/Passes/ForwardAdd.cginc"
            ENDCG
        }
    
        Pass
        {
            Name "SHADOWCASTER"
            Tags { "LightMode" = "ShadowCaster" }
        
            CGPROGRAM
            #pragma target 5.0
            #pragma only_renderers d3d11
        
            #pragma multi_compile_shadowcaster

            #pragma hull aHullShader
            #pragma vertex aVertexTessellationShader
            #pragma domain aDomainShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_SHADOWCASTER
        
            #include "Assets/HSSSS/Definitions/Overlay.cginc"
            #include "Assets/HSSSS/Passes/Shadow.cginc"
            ENDCG
        }
    
        Pass
        {
            Name "DEFERRED"
            Tags { "LightMode" = "Deferred" }

            CGPROGRAM
            #pragma target 5.0
            #pragma only_renderers d3d11
        
            #pragma multi_compile ___ UNITY_HDR_ON
            #pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
            #pragma multi_compile DIRLIGHTMAP_OFF DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE
            #pragma multi_compile DYNAMICLIGHTMAP_OFF DYNAMICLIGHTMAP_ON
        
            #pragma hull aHullShader
            #pragma vertex aVertexTessellationShader
            #pragma domain aDomainShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_DEFERRED
            #define _ALPHAHASHED_ON
        
            #include "Assets/HSSSS/Definitions/Overlay.cginc"
            #include "Assets/HSSSS/Passes/Deferred.cginc"
            ENDCG
        }
    }

    FallBack "Standard"
}