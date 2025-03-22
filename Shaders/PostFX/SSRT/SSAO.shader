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

        //
        // horizon calculation
        //

        // pass 1 : low
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 4
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 2 : medium
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 8
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 3 : high
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 12
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 4 : ultra
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 16
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 5 : low + subsample 1
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 4
            #define _SSAOSubSample_1
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 6 : medium + subsample 1
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 8
            #define _SSAOSubSample_1
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 7 : high + subsample 1
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 12
            #define _SSAOSubSample_1
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 8 : ultra + subsample 1
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 16
            #define _SSAOSubSample_1
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 9 : low + subsample 2
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 4
            #define _SSAOSubSample_2
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 10 : medium + subsample 2
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 8
            #define _SSAOSubSample_2
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 11 : high + subsample 2
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 12
            #define _SSAOSubSample_2
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 12 : ultra + subsample 2
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment IndirectOcclusion
            #define _SSAONumStride 16
            #define _SSAOSubSample_2
            #include "SSAO.cginc"
            ENDCG
        }

        //
        // apply ao
        //

        // pass 13 : apply ao mrt
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_mrt
            #pragma fragment ApplyOcclusionMRT
            #include "SSAO.cginc"
            ENDCG
        }
    }
}