Shader "Hidden/HSSSS/AmbientOcclusion"
{
    Properties
    {
        _MainTex ("MainTex", any) = "" {}
    }

    CGINCLUDE
    #pragma target 5.0
    #pragma exclude_renderers gles
    #pragma vertex vert_img
    ENDCG

    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always
        
        // pass 0 : hbao low
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 4
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 1 : hbao medium
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 8
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 2 : hbao high
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 12
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 3 : hbao ultra
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 16
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 4 : gtao low
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectOcclusion
            #define _VISBILITY_GTAO
            #define _SSAONumStride 4
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 5 : gtao medium
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectOcclusion
            #define _VISIBILITY_GTAO
            #define _SSAONumStride 8
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 6 : gtao high
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectOcclusion
            #define _VISIBILITY_GTAO
            #define _SSAONumStride 12
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 7 : gtao ultra
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectOcclusion
            #define _VISIBILITY_GTAO
            #define _SSAONumStride 16
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 8 : temporal filtering
        Pass
        {
            CGPROGRAM
            #pragma fragment DeinterleaveAO
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 9 : bilateral blur in x
        Pass
        {
            CGPROGRAM
            #pragma fragment BilateralBlur
            #define KERNEL_STEP 1
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 10 : bilateral blur in y
        Pass
        {
            CGPROGRAM
            #pragma fragment BilateralBlur
            #define KERNEL_STEP 2
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 11 : ao to GBuffer 0
        Pass
        {
            CGPROGRAM
            #pragma fragment ApplyOcclusionToGBuffer0
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 12 : ao to GBuffer 3
        Pass
        {
            CGPROGRAM
            #pragma fragment ApplyOcclusionToGBuffer3
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 13 : specular occlusion
        Pass
        {
            CGPROGRAM
            #pragma fragment ApplySpecularOcclusion
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 14 : debug
        Pass
        {
            CGPROGRAM
            #pragma fragment DebugAO
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 15 : blit depth
        Pass
        {
            CGPROGRAM
            #pragma fragment BlitDepth
            #include "SSAO.cginc"
            ENDCG
        }
    }
}