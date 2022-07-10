Shader "HSSSS/ForwardSkin" {
Properties {
    _MainTex ("Main Texture", 2D) = "white" {}
    _Color ("Main Color", Color) = (1,1,1,1)

    _SpecGlossMap ("SpecGlossMap", 2D) = "white" {}
    _SpecColor ("SpecColor", Color) = (1,1,1,1)
    _Metallic ("Specularity", Range(0, 1)) = 0
    _Smoothness ("Smoothness", Range(0, 1)) = 0

    _OcclusionMap ("OcclusionMap", 2D) = "white" {}
    _OcclusionStrength ("OcclusionStrength", Range(0, 1)) = 0

    _BumpMap ("BumpMap", 2D) = "bump" {}
    _BumpScale ("BumpScale", Float) = 1

    _BlendNormalMap ("BlendNormalMap", 2D) = "bump" {}
    _BlendNormalMapScale("BlendNormalMapScale", Float) = 1

    _DetailNormalMap ("DetailNormalMap", 2D) = "bump" {}
    _DetailNormalMapScale ("DetailNormalMapScale", Float) = 1

    _SssBrdfTex ("LUT", 2D) = "gray" {}
    _SssBias ("SSSBias", Range(0, 1)) = 0.5
    _SssScale ("SSSScale", Range(0, 1)) = 1
    _SssAoSaturation ("AOSaturation", Range(0, 1)) = 0.5
    _SssBumpBlur ("BumpBlur", Range(0, 1)) = 0.5

    _Thickness ("ThicknessMap", 2D) = "white" {}
    _TransColor ("TransColor", Color) = (1,0,0)
    _TransScale ("TransScale", Range(0, 1)) = 1
    _TransPower ("TransPower", Float) = 1
    _TransDistortion ("TransDistortion", Range(0, 1)) = 0.1
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

        #pragma multi_compile ___ _WET_SPECGLOSS
        #pragma multi_compile ___ _FACEWORKS_TYPE1
            
        #pragma vertex aVertexShader
        #pragma fragment aFragmentShader
        
        #define UNITY_PASS_FORWARDBASE
        
        #include "Assets/HSSSS/Definitions/ForwardSkin.cginc"
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

        #pragma multi_compile ___ _WET_SPECGLOSS
        #pragma multi_compile ___ _FACEWORKS_TYPE1
        
        #pragma vertex aVertexShader
        #pragma fragment aFragmentShader

        #define UNITY_PASS_FORWARDADD

        #include "Assets/HSSSS/Definitions/ForwardSkin.cginc"
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
        
        #include "Assets/HSSSS/Definitions/ForwardSkin.cginc"
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
        
        #include "Assets/HSSSS/Definitions/ForwardSkin.cginc"
        #include "Assets/HSSSS/Passes/Meta.cginc"

        ENDCG
    }
}

FallBack "VertexLit"
}
