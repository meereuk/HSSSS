Shader "HSSSS/Thin"
{
    Properties
    {
        _Color ("Main Color", Color) = (1,1,1,1)
        _MainTex ("Main Texture", 2D) = "white" {}
        _BumpMap ("BumpMap", 2D) = "bump" {}
        _BumpScale ("BumpScale", Float) = 1
    }




    SubShader
    {
        Tags
        {
            "Queue" = "Geometry" 
            "RenderType" = "Opaque"
        }
        LOD 300
    
        Pass
        {
            Name "SHADOWCASTER"
            Tags { "LightMode" = "ShadowCaster" }
        
            CGPROGRAM
            #pragma target 5.0
            #pragma exclude_renderers gles
        
            #pragma multi_compile_shadowcaster

            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_SHADOWCASTER
            #define UNITY_STANDARD_USE_DITHER_MASK
        
            #include "Assets/HSSSS/Definitions/Thin.cginc"
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

            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader

            #define UNITY_PASS_DEFERRED

            #include "Assets/HSSSS/Definitions/Thin.cginc"
            #include "Assets/HSSSS/Passes/Deferred.cginc"
            ENDCG
        }
    }

    FallBack "Unlit/Color"
}