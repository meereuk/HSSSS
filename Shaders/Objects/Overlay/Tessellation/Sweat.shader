Shader "HSSSS/Overlay/Tessellation/Sweat"
{
    Properties
    {
        [Header(Albedo)]
        _MainTex ("Main Texture", 2D) = "white" {}
        _Color ("Main Color", Color) = (1,1,1,1)

        [Header(Specular)]
        _DetailMask ("Wet Mask", 2D) = "white" {}
        _Metallic ("Specularity", Range(0, 1)) = 0
        _Smoothness ("Smoothness", Range(0, 1)) = 0

        [Header(Normal)]
        _BumpMap ("BumpMap", 2D) = "bump" {}
        _BumpScale ("BumpScale", Float) = 1

        [Header(Tessellation)]
        _DispTex ("HeightMap", 2D) = "black" {}
        _Displacement ("Displacement", Range(0, 30)) = 0.1
        _Phong ("PhongStrength", Range(0, 1)) = 0.5
        _EdgeLength ("EdgeLength", Range(2, 50)) = 2
    }

    CGINCLUDE
        #define A_TESSELLATION_ON
        #define _TESSELLATIONMODE_COMBINED
        #define _ALPHAPREMULTIPLY_ON
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

            Blend One OneMinusSrcAlpha
            ZWrite Off

            CGPROGRAM
            #pragma target gl4.1
            #pragma exclude_renderers gles

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            
            #pragma hull aHullShader
            #pragma vertex aVertexTessellationShader
            #pragma domain aDomainShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_FORWARDBASE
        
            #include "Assets/HSSSS/Definitions/Sweat.cginc"
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
            #pragma target gl4.1
            #pragma exclude_renderers gles
        
            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog
        
            #pragma hull aHullShader
            #pragma vertex aVertexTessellationShader
            #pragma domain aDomainShader
            #pragma fragment aFragmentShader

            #define UNITY_PASS_FORWARDADD

            #include "Assets/HSSSS/Definitions/Sweat.cginc"
            #include "Assets/HSSSS/Passes/ForwardAdd.cginc"
            ENDCG
        }
    }

    FallBack "VertexLit"
}