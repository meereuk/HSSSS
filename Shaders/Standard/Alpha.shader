Shader "HSSSS/Alpha" {
Properties {
    _Cutoff ("Cutoff", Range(0, 1)) = 0.5

    _MainTex ("Main Texture", 2D) = "white" {}
    _Color ("Main Color", Color) = (1,1,1,1)

    _SpecGlossMap ("SpecGlossMap", 2D) = "white" {}
    _Metallic ("Specularity", Range(0, 1)) = 0
    _Smoothness ("Smoothness", Range(0, 1)) = 0

    _OcclusionMap ("OcclusionMap", 2D) = "white" {}
    _OcclusionStrength ("OcclusionStrength", Range(0, 1)) = 0

    _BumpMap ("BumpMap", 2D) = "bump" {}
    _BumpScale ("BumpScale", Float) = 1

    _DetailNormalMap ("DetailNormalMap", 2D) = "bump" {}
    _DetailNormalMapScale ("DetailNormalMapScale", Float) = 1
}

SubShader {
    Tags { 
        "Queue" = "Transparent-1000" 
        "RenderType" = "Transparent"
    }
    LOD 300

    Pass {
        Name "FORWARD" 
        Tags { "LightMode" = "ForwardBase" }

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite On

        CGPROGRAM
        #pragma target 3.0
        #pragma exclude_renderers gles
        
        #pragma multi_compile_fwdbase
        #pragma multi_compile_fog
            
        #pragma vertex aVertexShader
        #pragma fragment aFragmentShader
        
        #define UNITY_PASS_FORWARDBASE
        #define _ALPHABLEND_ON
        #define _ALPHATEST_ON
        
        #include "Assets/HSSSS/Definitions/Core.cginc"
        #include "Assets/HSSSS/Passes/ForwardBase.cginc"

        ENDCG
    }
    
    Pass {
        Name "FORWARD_DELTA"
        Tags { "LightMode" = "ForwardAdd" }
        
        Blend SrcAlpha One
        ZWrite Off

        CGPROGRAM
        #pragma target 3.0
        #pragma exclude_renderers gles
        
        #pragma multi_compile_fwdadd_fullshadows
        #pragma multi_compile_fog
        
        #pragma vertex aVertexShader
        #pragma fragment aFragmentShader

        #define UNITY_PASS_FORWARDADD
        #define _ALPHABLEND_ON
        #define _ALPHATEST_ON

        #include "Assets/HSSSS/Definitions/Core.cginc"
        #include "Assets/HSSSS/Passes/ForwardAdd.cginc"

        ENDCG
    }
    
    Pass {
        Name "SHADOWCASTER"
        Tags { "LightMode" = "ShadowCaster" }

        CGPROGRAM
        #pragma target 3.0
        #pragma exclude_renderers gles
        
        #pragma multi_compile_shadowcaster

        #pragma vertex aVertexShader
        #pragma fragment aFragmentShader
        
        #define UNITY_PASS_SHADOWCASTER
        #define _ALPHABLEND_ON
        #define _ALPHATEST_ON
        
        #include "Assets/HSSSS/Definitions/Core.cginc"
        #include "Assets/HSSSS/Passes/Shadow.cginc"

        ENDCG
    }
    
    Pass {
        Name "Meta"
        Tags { "LightMode" = "Meta" }
        Cull Off

        CGPROGRAM
        #pragma target 3.0
        #pragma exclude_renderers nomrt gles
                
        #pragma vertex aVertexShader
        #pragma fragment aFragmentShader
        
        #define UNITY_PASS_META
        
        #include "Assets/HSSSS/Definitions/Core.cginc"
        #include "Assets/HSSSS/Passes/Meta.cginc"

        ENDCG
    }
}

FallBack "VertexLit"
}