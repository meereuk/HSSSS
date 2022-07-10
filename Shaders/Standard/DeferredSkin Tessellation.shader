Shader "HSSSS/DeferredSkin Tessellation" {
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

    _Thickness ("ThicknessMap", 2D) = "white" {}

    _DispTex ("HeightMap", 2D) = "black" {}
    _Displacement ("Displacement", Range(0, 30)) = 0.1
    _Phong ("PhongStrength", Range(0, 1)) = 0.5
    _EdgeLength ("EdgeLength", Range(2, 50)) = 2

    //_EmissionMap ("'EmissionMap' {Visualize:{RGB, A}}", 2D) = "white" {}
    //[HDR]_EmissionColor ("'EmissionColor' {}", Color) = (0,0,0,1)
    //[Gamma]_Emission ("'Emission' {Min:0, Max:1}", Float) = 0

    //[HDR]_RimColor ("'RimColor' {}", Color) = (0,0,0,1)
    //[Gamma]_RimWeight ("'Weight' {Min:0, Max:1}", Float) = 1
    //[Gamma]_RimBias ("'Fill' {Min:0, Max:1}", Float) = 0
    //_RimPower ("'Falloff' {Min:0.01}", Float) = 4
}

CGINCLUDE
    #define A_TESSELLATION_ON
ENDCG

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
        
        #include "Assets/HSSSS/Definitions/DeferredSkin.cginc"
        #include "Assets/HSSSS/Passes/ForwardBase.cginc"

        ENDCG
    }
    
    Pass {
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
        #define _TESSELLATIONMODE_COMBINED

        #include "Assets/HSSSS/Definitions/DeferredSkin.cginc"
        #include "Assets/HSSSS/Passes/ForwardAdd.cginc"

        ENDCG
    }
    
    Pass {
        Name "SHADOWCASTER"
        Tags { "LightMode" = "ShadowCaster" }
        
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
        
        #include "Assets/HSSSS/Definitions/DeferredSkin.cginc"
        #include "Assets/HSSSS/Passes/Shadow.cginc"

        ENDCG
    }
    
    Pass {
        Name "DEFERRED"
        Tags { "LightMode" = "Deferred" }

        CGPROGRAM
        #pragma target gl4.1
        #pragma exclude_renderers nomrt gles
        
        #pragma multi_compile ___ UNITY_HDR_ON
        #pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
        #pragma multi_compile DIRLIGHTMAP_OFF DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE
        #pragma multi_compile DYNAMICLIGHTMAP_OFF DYNAMICLIGHTMAP_ON

        #pragma multi_compile ___ _WET_SPECGLOSS
        
        #pragma hull aHullShader
        #pragma vertex aVertexTessellationShader
        #pragma domain aDomainShader
        #pragma fragment aFragmentShader
        
        #define UNITY_PASS_DEFERRED
        #define _TESSELLATIONMODE_COMBINED
        
        #include "Assets/HSSSS/Definitions/DeferredSkin.cginc"
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
        
        #include "Assets/HSSSS/Definitions/DeferredSkin.cginc"
        #include "Assets/HSSSS/Passes/Meta.cginc"

        ENDCG
    }
}

FallBack "VertexLit"
}
