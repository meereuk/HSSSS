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

        // pass 0 : zbuffer prepass
        Pass
        {
            CGPROGRAM
            #pragma fragment ZBufferPrePass
            #include "SSAO.cginc"
            ENDCG
        }

        //
        // HBAO MAIN PASS
        //

        // pass 1 : hbao low
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 4
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 2 : hbao medium
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 8
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 3 : hbao high
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 12
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 4 : hbao ultra
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 16
            #include "SSAO.cginc"
            ENDCG
        }

        //
        // GTAO MAIN PASS
        //

        // pass 5 : gtao low
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectOcclusion
            #define _VISBILITY_GTAO
            #define _SSAONumStride 4
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 6 : gtao medium
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectOcclusion
            #define _VISIBILITY_GTAO
            #define _SSAONumStride 8
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 7 : gtao high
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectOcclusion
            #define _VISIBILITY_GTAO
            #define _SSAONumStride 12
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 8 : gtao ultra
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectOcclusion
            #define _VISIBILITY_GTAO
            #define _SSAONumStride 16
            #include "SSAO.cginc"
            ENDCG
        }

        //
        // 
        //

        // pass 9 : spatio denoiser 1
        Pass
        {
            CGPROGRAM
            #pragma fragment SpatialDenoiser
            #define KERNEL_STEP 1
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 10 : spatio denoiser 2
        Pass
        {
            CGPROGRAM
            #pragma fragment SpatialDenoiser
            #define KERNEL_STEP 2
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 11 : temporal denoiser
        Pass
        {
            CGPROGRAM
            #pragma fragment TemporalDenoiser
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 12 : ao to GBuffer 0
        Pass
        {
            CGPROGRAM
            #pragma fragment ApplyOcclusionToGBuffer0
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 13 : ao to GBuffer 3
        Pass
        {
            CGPROGRAM
            #pragma fragment ApplyOcclusionToGBuffer3
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 14 : specular occlusion
        Pass
        {
            CGPROGRAM
            #pragma fragment ApplySpecularOcclusion
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 15 : debug
        Pass
        {
            CGPROGRAM
            #pragma fragment DebugAO
            #include "SSAO.cginc"
            ENDCG
        }
    }
}