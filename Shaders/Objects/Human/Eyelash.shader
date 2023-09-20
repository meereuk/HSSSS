Shader "HSSSS/Human/Eyelash"
{
    Properties
    {
        [Header(Albedo)]
        _MainTex ("Main Texture", 2D) = "white" {}
        _Color ("Main Color", Color) = (1,1,1,1)

        [Space(8)][Header(Emission)]
        _EmissionMap ("Emission Map", 2D) = "white" {}
        _EmissionColor ("Emission Color", Color) = (0, 0, 0, 1)
    }

    CGINCLUDE
        #define _ALPHABLEND_ON
    ENDCG

    SubShader
    {
        Tags
        {
            "Queue" = "AlphaTest"
            "RenderType" = "Transparent"
            "IgnoreProjector" = "True"
            "ForceNoShadowCasting" = "True"
        }

        LOD 300

        Pass
        {
            Name "FORWARD" 
            Tags { "LightMode" = "ForwardBase" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off

            CGPROGRAM
            #pragma target 5.0
            #pragma only_renderers d3d11

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            
            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_FORWARDBASE
        
            #include "Assets/HSSSS/Definitions/Overlay.cginc"
            #include "Assets/HSSSS/Passes/ForwardBase.cginc"
            ENDCG
        }
    
        Pass
        {
            Name "FORWARD_DELTA"
            Tags { "LightMode" = "ForwardAdd" }
        
            Blend SrcAlpha One
            ZWrite Off
            Cull Off

            CGPROGRAM
            #pragma target 5.0
            #pragma only_renderers d3d11
        
            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog
        
            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader

            #define UNITY_PASS_FORWARDADD

            #include "Assets/HSSSS/Definitions/Overlay.cginc"
            #include "Assets/HSSSS/Passes/ForwardAdd.cginc"
            ENDCG
        }
    }

    FallBack "Standard"
}