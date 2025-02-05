Shader "Hidden/HSSSS/AmbientOcclusion"
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

        // pass 0 : zbuffer prepass
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment ZBufferPrePass
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 1 : zbuffer downsampling
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment ZBufferDownSample
            #include "SSAO.cginc"
            ENDCG
        }

        //
        // horizon calculation
        //

        // pass 2 : low
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 16
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 3 : medium
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 32
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 4 : high
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 48
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 5 : ultra
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 64
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 6 : decoding pass
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment DecodeAO
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 7 : bilinear interpolation
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment Interpolate
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 8 : spatio denoiser
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment SpatialDenoiser
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 9 : spatio denoiser
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment SpatialDenoiser
            #define BLUR_YAXIS
            #include "SSAO.cginc"
            ENDCG
        }

        //
        // apply ao
        //

        // pass 10 : ao to GBuffer 0
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment ApplyOcclusionToGBuffer0
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 11 : ao to GBuffer 3
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment ApplyOcclusionToGBuffer3
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 12 : specular occlusion
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment ApplySpecularOcclusion
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 13 : debug
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment DebugAO
            #include "SSAO.cginc"
            ENDCG
        }
    }
}