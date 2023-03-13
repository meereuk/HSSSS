Shader "HSSSS/Nature/Water"
{
    Properties
    {
        [Header(Color)]
        _Color ("Main Color", Color) = (1,1,1,1)

        [Header(Absorption)]
        _SpecColor ("AbsorptionColor", Color) = (1, 1, 1, 1)
        _Absorption ("Absorption", Float) = 1

        [Header(Transmission)]
        _TransColor ("TransmissionColor", Color) = (1, 1, 1, 1)
        _TransScale ("TransScale", Range(0, 1)) = 1
        _TransPower ("TransPower", Range(0, 8)) = 1
        _TransDistortion ("TransDistortion", Range(0, 1)) = 1

        [Header(Physics)]
        _Metallic ("Specularity", Range(0, 1)) = 0
        _Smoothness ("Smoothness", Range(0, 1)) = 0

        [Header(Normals)]
        _BumpMap ("BumpMap", 2D) = "bump" {}
        _BumpScale ("BumpScale", Float) = 1

        _DetailNormalMap ("DetailNormalMap", 2D) = "bump" {}
        _DetailNormalMapScale ("DetailNormalMapScale", FLoat) = 1

        [Header(Distortion)]
        _DistortWeight ("DistortWeight", Range(0, 1)) = 1

        [Header(Tessellation)]
        _DispTex ("HeightMap", 2D) = "black" {}
        _Displacement ("Displacement", Range(0, 30)) = 0.1
        _Phong ("PhongStrength", Range(0, 1)) = 0.5
        _EdgeLength ("EdgeLength", Range(2, 50)) = 2
    }

    CGINCLUDE
        #define A_TESSELLATION_ON
    ENDCG

    SubShader
    {
        Tags
        {
            "Queue" = "AlphaTest"
            "RenderType" = "Opaque"
            "IgnoreProjector" = "True"
            "ForceNoShadowCasting" = "True"
        }

        LOD 500

        GrabPass
        {
        }

        Pass
        {
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
        
            #include "Assets/HSSSS/Definitions/Water.cginc"
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
            #define _TESSELLATIONMODE_COMBINED

            #include "Assets/HSSSS/Definitions/Water.cginc"
            #include "Assets/HSSSS/Passes/ForwardAdd.cginc"
            ENDCG
        }
    }
}
