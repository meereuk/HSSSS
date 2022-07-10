Shader "HSSSS/HairBase Tessellation" {
Properties {
    _Cutoff ("Cutoff", Range(0, 1)) = 0.5
    
    _MainTex ("Main Texture", 2D) = "white" {}
    _Color ("Main Color", Color) = (1,1,1,1)

    _DispTex ("HeightMap", 2D) = "black" {}
    _Displacement ("Displacement", Range(0, 30)) = 0.1
    _Phong ("PhongStrength", Range(0, 1)) = 0.5
    _EdgeLength ("EdgeLength", Range(2, 50)) = 2
}

CGINCLUDE
    #define A_TESSELLATION_ON
ENDCG

SubShader {
    Tags { 
        "Queue" = "AlphaTest" 
        "RenderType" = "Opaque"
    }
    LOD 400

    Pass {
        Name "FORWARD" 
        Tags { "LightMode" = "ForwardBase" }

        Cull Off

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
        #define _TESSELLATIONMODE_COMBINED
        #define _ALPHATEST_ON
        
        #include "Assets/HSSSS/Definitions/HairBase.cginc"
        #include "Assets/HSSSS/Passes/ForwardBase.cginc"

        ENDCG
    }
    
    Pass {
        Name "FORWARD_DELTA"
        Tags { "LightMode" = "ForwardAdd" }
        
        Cull Off
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
        #define _TESSELLATIONMODE_COMBINED
        #define _ALPHATEST_ON

        #include "Assets/HSSSS/Definitions/HairBase.cginc"
        #include "Assets/HSSSS/Passes/ForwardAdd.cginc"

        ENDCG
    }
    
    Pass {
        Name "SHADOWCASTER"
        Tags { "LightMode" = "ShadowCaster" }

        Cull Off
        
        CGPROGRAM
        #pragma target gl4.1
        #pragma exclude_renderers gles
        
        #pragma multi_compile_shadowcaster

        #pragma hull aHullShader
        #pragma vertex aVertexTessellationShader
        #pragma domain aDomainShader
        #pragma fragment aFragmentShader
        
        #define UNITY_PASS_SHADOWCASTER
        #define _TESSELLATIONMODE_COMBINED
        #define _ALPHATEST_ON
        
        #include "Assets/HSSSS/Definitions/HairBase.cginc"
        #include "Assets/HSSSS/Passes/Shadow.cginc"

        ENDCG
    }
    
    Pass {
        Name "DEFERRED"
        Tags { "LightMode" = "Deferred" }

        Cull Off

        CGPROGRAM
        #pragma target gl4.1
        #pragma exclude_renderers nomrt gles
        
        #pragma multi_compile ___ UNITY_HDR_ON
        #pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
        #pragma multi_compile DIRLIGHTMAP_OFF DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE
        #pragma multi_compile DYNAMICLIGHTMAP_OFF DYNAMICLIGHTMAP_ON
        
        #pragma hull aHullShader
        #pragma vertex aVertexTessellationShader
        #pragma domain aDomainShader
        #pragma fragment aFragmentShader
        
        #define UNITY_PASS_DEFERRED
        #define _TESSELLATIONMODE_COMBINED
        #define _ALPHATEST_ON
        
        #include "Assets/HSSSS/Definitions/HairBase.cginc"
        #include "Assets/HSSSS/Passes/Deferred.cginc"

        ENDCG
    }
    
    Pass {
        Name "Meta"
        Tags { "LightMode" = "Meta" }
        Cull Off

        CGPROGRAM
        #pragma target gl4.1
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
