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

        //
        // apply ao
        //

        // pass 5 : apply ao mrt
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