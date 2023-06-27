Shader "Hidden/HSSSS/GlobalIllumination"
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

        // pass 0 : g-buffer prepass
        Pass
        {
            CGPROGRAM
            #pragma fragment GBufferPrePass
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 1 : low
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectDiffuse
            #define _SSGINumStride 4
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 2 : medium
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectDiffuse
            #define _SSGINumStride 8
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 3 : high
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectDiffuse
            #define _SSGINumStride 12
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 4 : ultra
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectDiffuse
            #define _SSGINumStride 16
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 5 : temporal filter
        Pass
        {
            CGPROGRAM
            #pragma fragment TemporalFilter
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 6 : denoising step 1
        Pass
        {
            CGPROGRAM
            #pragma fragment BilateralBlur
            #define KERNEL_STEP 1
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 7 : denoising step 2
        Pass
        {
            CGPROGRAM
            #pragma fragment BilateralBlur
            #define KERNEL_STEP 2
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 8 : denoising step 3
        Pass
        {
            CGPROGRAM
            #pragma fragment BilateralBlur
            #define KERNEL_STEP 4
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 9 : denoising step 4
        Pass
        {
            CGPROGRAM
            #pragma fragment BilateralBlur
            #define KERNEL_STEP 8
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 10 : median filter
        Pass
        {
            CGPROGRAM
            #pragma fragment MedianFilter
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 11 : collect gi
        Pass
        {
            CGPROGRAM
            #pragma fragment CollectGI
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 12 : store zbuffer
        Pass
        {
            CGPROGRAM
            #pragma fragment BlitZBuffer
            #include "SSGI.cginc"
            ENDCG
        }
    }
}