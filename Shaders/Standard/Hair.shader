Shader "HSSSS/Hair" {
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

    _WrapDiffuse ("WrapDiffuse", Range(0, 1)) = 0.25
    _AnisoAngle ("AnisoAngle", Range(0, 180)) = 90

    _NoiseMap ("NoiseMap", 2D) = "white" {}
    _ShiftMap ("ShiftMap", 2D) = "white" {}

    _SpecColor ("SpecColor", Color) = (1,1,1,1)
    _SpecColor_3 ("SpecColor", Color) = (1,1,1,1)

    _HighlightWidth0 ("Width0", Range(0, 1)) = 0.25
    _HighlightShift0 ("Shift0", Float) = 0

    _HighlightWidth1 ("Width1", Range(0, 1)) = 0.25
    _HighlightShift1 ("Shift1", Float) = 0
}

SubShader {
    Tags{
        "Queue" = "AlphaTest+1"
        "IgnoreProjector" = "True"
        "RenderType" = "TransparentCutout"
    }
    LOD 400

    Pass {
        Name "FORWARD" 
        Tags { "LightMode" = "ForwardBase" }

        Cull Off

        CGPROGRAM
        #pragma target 3.0
        #pragma exclude_renderers gles
        
        #pragma multi_compile_fwdbase
        #pragma multi_compile_fog
            
        #pragma vertex aVertexShader
        #pragma fragment aFragmentShader
        
        #define UNITY_PASS_FORWARDBASE
        #define _ALPHATEST_ON

        #include "Assets/HSSSS/Definitions/Hair.cginc"
        #include "Assets/HSSSS/Passes/ForwardBase.cginc"

        ENDCG
    }
    
    Pass {
        Name "FORWARD_DELTA"
        Tags { "LightMode" = "ForwardAdd" }
        
        Blend One One
        ZWrite Off
        Cull Off

        CGPROGRAM
        #pragma target 3.0
        #pragma exclude_renderers gles
        
        #pragma multi_compile_fwdadd_fullshadows
        #pragma multi_compile_fog
        
        #pragma vertex aVertexShader
        #pragma fragment aFragmentShader

        #define UNITY_PASS_FORWARDADD
        #define _ALPHATEST_ON

        #include "Assets/HSSSS/Definitions/Hair.cginc"
        #include "Assets/HSSSS/Passes/ForwardAdd.cginc"

        ENDCG
    }
    
    Pass {
        Name "TRANSLUCENT_BACK_FORWARD" 
        Tags { "LightMode" = "ForwardBase" }

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        ZTest Less
        Cull Front

        CGPROGRAM
        #pragma target 3.0
        #pragma exclude_renderers gles
        
        #pragma multi_compile_fwdbase
        #pragma multi_compile_fog
            
        #pragma vertex aVertexShader
        #pragma fragment aFragmentShader
        
        #define UNITY_PASS_FORWARDBASE
        #define _ALPHABLEND_ON

        #include "Assets/HSSSS/Definitions/Hair.cginc"
        #include "Assets/HSSSS/Passes/ForwardBase.cginc"

        ENDCG
    }
    
    Pass {
        Name "TRANSLUCENT_BACK_FORWARD_DELTA"
        Tags { "LightMode" = "ForwardAdd" }
        
        Blend SrcAlpha One
        ZWrite Off
        ZTest Less
        Cull Front

        CGPROGRAM
        #pragma target 3.0
        #pragma exclude_renderers gles
        
        #pragma multi_compile_fwdadd_fullshadows
        #pragma multi_compile_fog
        
        #pragma vertex aVertexShader
        #pragma fragment aFragmentShader

        #define UNITY_PASS_FORWARDADD
        #define _ALPHABLEND_ON

        #include "Assets/HSSSS/Definitions/Hair.cginc"
        #include "Assets/HSSSS/Passes/ForwardAdd.cginc"

        ENDCG
    }
    
    Pass {
        Name "TRANSLUCENT_FRONT_FORWARD" 
        Tags { "LightMode" = "ForwardBase" }

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        ZTest Less

        CGPROGRAM
        #pragma target 3.0
        #pragma exclude_renderers gles
        
        #pragma multi_compile_fwdbase
        #pragma multi_compile_fog
            
        #pragma vertex aVertexShader
        #pragma fragment aFragmentShader
        
        #define UNITY_PASS_FORWARDBASE
        #define _ALPHABLEND_ON

        #include "Assets/HSSSS/Definitions/Hair.cginc"
        #include "Assets/HSSSS/Passes/ForwardBase.cginc"

        ENDCG
    }
    
    Pass {
        Name "TRANSLUCENT_FRONT_FORWARD_DELTA"
        Tags { "LightMode" = "ForwardAdd" }
        
        Blend SrcAlpha One
        ZWrite Off
        ZTest Less

        CGPROGRAM
        #pragma target 3.0
        #pragma exclude_renderers gles
        
        #pragma multi_compile_fwdadd_fullshadows
        #pragma multi_compile_fog
        
        #pragma vertex aVertexShader
        #pragma fragment aFragmentShader

        #define UNITY_PASS_FORWARDADD
        #define _ALPHABLEND_ON

        #include "Assets/HSSSS/Definitions/Hair.cginc"
        #include "Assets/HSSSS/Passes/ForwardAdd.cginc"

        ENDCG
    }
    
    Pass {
        Name "SHADOWCASTER"
        Tags { "LightMode" = "ShadowCaster" }
        
        Cull Off

        CGPROGRAM
        #pragma target 3.0
        #pragma exclude_renderers gles
        
        #pragma multi_compile_shadowcaster

        #pragma vertex aVertexShader
        #pragma fragment aFragmentShader
        
        #define UNITY_PASS_SHADOWCASTER
        #define _ALPHATEST_ON
        
        #include "Assets/HSSSS/Definitions/Hair.cginc"
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
        
        #include "Assets/HSSSS/Definitions/Hair.cginc"
        #include "Assets/HSSSS/Passes/Meta.cginc"

        ENDCG
    }
}

FallBack "VertexLit"
}
