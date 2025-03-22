Shader "Hidden/HSSSS/GlobalIllumination"
{
    Properties
    {
        _MainTex ("MainTex", any) = "" {}
    }

    CGINCLUDE
    #pragma target 5.0
    #pragma only_renderers d3d11
    ENDCG

    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always

        // pass 0 : g-buffer prepass
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment GBufferPrePass
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 1 : low
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_mrt
            #pragma fragment IndirectDiffuse
            #define _SSGINumStride 4
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 2 : medium
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_mrt
            #pragma fragment IndirectDiffuse
            #define _SSGINumStride 8
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 3 : high
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_mrt
            #pragma fragment IndirectDiffuse
            #define _SSGINumStride 12
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 4 : ultra
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_mrt
            #pragma fragment IndirectDiffuse
            #define _SSGINumStride 16
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 5 : temporal filter
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_mrt
            #pragma fragment TemporalFilter
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 6 : pre blur
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_mrt
            #pragma fragment BilateralBlur
            #define KERNEL_STEP 1
            #define _SAMPLE_FLOP
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 7 : main blur
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_mrt
            #pragma fragment BilateralBlur
            #define KERNEL_STEP 2
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 8 : postpass blur
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_mrt
            #pragma fragment BilateralBlur
            #define KERNEL_STEP 4
            #define _SAMPLE_FLOP
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 9 : store history buffer
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_mrt
            #pragma fragment StoreHistory
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 10 : collect gi
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment CollectGI
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 11 : blit flip to flop
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_mrt
            #pragma fragment BlitFlipToFlop
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 12 : blit flop to flip
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_mrt
            #pragma fragment BlitFlopToFlip
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 13 : debug
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment DebugGI
            #include "SSGI.cginc"
            ENDCG
        }
    }
}