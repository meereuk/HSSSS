Shader "HSSSS/Overlay/ShadowReceiver"
{
    Properties
    {
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Geometry"
            "RenderType" = "Opaque"
        }

        LOD 300

        GrabPass
        {
        }

        Pass
        {
            Name "FORWARD" 
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM
            #pragma target 5.0
            #pragma only_renderers d3d11

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            #pragma multi_compile ___ _PCF_ON
            
            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader
        
            #define UNITY_PASS_FORWARDBASE

            #include "Assets/HSSSS/Definitions/Receiver.cginc"
            #include "Assets/HSSSS/Passes/ForwardBase_.cginc"
            ENDCG
        }
    
        Pass
        {
            Name "FORWARD_DELTA"
            Tags { "LightMode" = "ForwardAdd" }
        
            Blend One One
            ZWrite Off

            CGPROGRAM
            #pragma target 5.0
            #pragma only_renderers d3d11
        
            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog
            #pragma multi_compile ___ _PCF_ON
        
            #pragma vertex aVertexShader
            #pragma fragment aFragmentShader

            #define UNITY_PASS_FORWARDADD

            #include "Assets/HSSSS/Definitions/Receiver.cginc"
            #include "Assets/HSSSS/Passes/ForwardAdd_.cginc"
            ENDCG
        }
    }

    FallBack "Standard"
}