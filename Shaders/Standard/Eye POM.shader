Shader "HSSSS/Eye POM" {
Properties {
    _MainTex ("IrisTex", 2D) = "white" {}
    _Color("IrisColor", Color) = (1,1,1,1)

    _ScleraTex("ScleraTex", 2D) = "white" {}
    _SpecColor("ScleraColor", Color) = (1,1,1,1)

    _SpecGlossMap("SpecGlossMap", 2D) = "white" {}
    
    _Metallic ("Metallic", Range(0, 1)) = 0
    _Smoothness ("Smoothness", Range(0, 1)) = 0

    _BumpMap("BumpMap", 2D) = "bump" {}
    _BumpScale("BumpScale", Float) = 1

    _DetailNormalMap("DetailNormalMap", 2D) = "bump" {}
    _DetailNormalMapScale("DetailNormalMapScale", Float) = 1

    _Parallax ("Parallax", Range(0, 0.08)) = 0
    _PupilSize ("PupilSize", Range(0, 1.0)) = 0
}

SubShader {
    Tags { 
        "Queue" = "Geometry" 
        "RenderType" = "Opaque"
    }
    LOD 400

    Pass {
        Name "FORWARD" 
        Tags { "LightMode" = "ForwardBase" }

        CGPROGRAM
        #pragma target 3.0
        #pragma exclude_renderers gles
        
        #pragma multi_compile_fwdbase
        #pragma multi_compile_fog
            
        #pragma vertex aVertexShader
        #pragma fragment aFragmentShader
        
        #define UNITY_PASS_FORWARDBASE
        
        #include "Assets/HSSSS/Definitions/Eyeball.cginc"
        #include "Assets/HSSSS/Passes/ForwardBase.cginc"

        ENDCG
    }
    
    Pass {
        Name "FORWARD_DELTA"
        Tags { "LightMode" = "ForwardAdd" }
        
        Blend One One
        ZWrite Off

        CGPROGRAM
        #pragma target 3.0
        #pragma exclude_renderers gles
        
        #pragma multi_compile_fwdadd_fullshadows
        #pragma multi_compile_fog
        
        #pragma vertex aVertexShader
        #pragma fragment aFragmentShader

        #define UNITY_PASS_FORWARDADD

        #include "Assets/HSSSS/Definitions/Eyeball.cginc"
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
        
        #include "Assets/HSSSS/Definitions/Eyeball.cginc"
        #include "Assets/HSSSS/Passes/Shadow.cginc"

        ENDCG
    }
    
    Pass {
        Name "DEFERRED"
        Tags { "LightMode" = "Deferred" }

        CGPROGRAM
        #pragma target 3.0
        #pragma exclude_renderers nomrt gles
        
        #pragma multi_compile ___ UNITY_HDR_ON
        #pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
        #pragma multi_compile DIRLIGHTMAP_OFF DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE
        #pragma multi_compile DYNAMICLIGHTMAP_OFF DYNAMICLIGHTMAP_ON
        
        #pragma vertex aVertexShader
        #pragma fragment aFragmentShader
        
        #define UNITY_PASS_DEFERRED
        
        #include "Assets/HSSSS/Definitions/Eyeball.cginc"
        #include "Assets/HSSSS/Passes/Deferred.cginc"

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
        
        #include "Assets/HSSSS/Definitions/Eyeball.cginc"
        #include "Assets/HSSSS/Passes/Meta.cginc"

        ENDCG
    }
}

FallBack "VertexLit"
}
