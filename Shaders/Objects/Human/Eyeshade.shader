Shader "HSSSS/Human/Eyeshade"
{
    Properties
    {
        [Header(Albedo)]
        _MainTex ("Main Texture", 2D) = "white" {}
        _Color ("Main Color", Color) = (1,1,1,1)

        [Space(8)][Header(Tessellation)]
        _DispTex ("HeightMap", 2D) = "black" {}
        _Displacement ("Displacement", Range(0, 30)) = 0.1
        _Phong ("PhongStrength", Range(0, 1)) = 0.5
        _EdgeLength ("EdgeLength", Range(2, 50)) = 2
    }

    SubShader
    {
        CGINCLUDE
            #define A_TESSELLATION_ON
            #define _TESSELLATIONMODE_COMBINED
            #define _ALPHABLEND_ON
        ENDCG

        Tags
        {
            "Queue" = "AlphaTest+2"
            "RenderType" = "Opaque"
            "IgnoreProjector" = "True"
            "ForceNoShadowCasting" = "True"
            "PerformanceChecks" = "False"
        }

        LOD 400

        Pass
        {
            Name "BASE" 
            Tags { "LightMode" = "ForwardBase" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            CGPROGRAM
            #pragma target 5.0
            #pragma only_renderers d3d11

            #pragma multi_compile_fog
            
            #pragma hull aHullShader
            #pragma vertex aVertexTessellationShader
            #pragma domain aDomainShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_FORWARDBASE
        
            #include "Assets/HSSSS/Definitions/Unlit.cginc"
            #include "Assets/HSSSS/Passes/ForwardBase.cginc"
            ENDCG
        }
    }

    SubShader
    {
        CGINCLUDE
            #define _ALPHABLEND_ON
        ENDCG
        
        Tags
        {
            "Queue" = "AlphaTest+2"
            "RenderType" = "Opaque"
            "IgnoreProjector" = "True"
            "ForceNoShadowCasting" = "True"
        }

        LOD 300

        Pass
        {
            Name "BASE" 
            Tags { "LightMode" = "ForwardBase" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            CGPROGRAM
            #pragma target 5.0
            #pragma only_renderers d3d11

            #pragma multi_compile_fog
            
            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_FORWARDBASE
            #define _ALPHABLEND_ON
        
            #include "Assets/HSSSS/Definitions/Unlit.cginc"
            #include "Assets/HSSSS/Passes/ForwardBase.cginc"
            ENDCG
        }
    }

    FallBack "Standard"
}