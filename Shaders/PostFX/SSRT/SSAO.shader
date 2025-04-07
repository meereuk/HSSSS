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

        // pass 14 : apply ao mrt (multibounce ao)
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_mrt
            #pragma fragment ApplyOcclusionMRT
            #define _MULTIBOUNCE_OCCLUSION
            #include "SSAO.cginc"
            ENDCG
        }

        //
        // debug ao
        //

        // pass 15 : debug ao
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag
            #include "SSAO.cginc"

            half4 frag(v2f_img IN) : SV_TARGET
            {
                return half4(SampleMask(IN.uv).www, 1.0f);
            }
            ENDCG
        }

        // pass 15 : debug ao (multibounce ao)
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag
            #include "SSAO.cginc"

            half4 frag(v2f_img IN) : SV_TARGET
            {
                half ao = SampleMask(IN.uv).w;

                half3 albedo = SampleGBuffer0(IN.uv).xyz;

                half3 a =  2.0404f * albedo - 0.3324f;
                half3 b = -4.7951f * albedo + 0.6417f;
                half3 c =  2.7552f * albedo + 0.6903f;

                half3 vis = max(ao, mad(mad(ao, a, b), ao, c) * ao);

                return half4(vis, 1.0f);
            }
            ENDCG
        }

        // pass 17 : debug bent normal
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag
            #include "SSAO.cginc"

            half4 frag(v2f_img IN) : SV_TARGET
            {
                return half4(mad(SampleMask(IN.uv).xyz, 0.5f, 0.5f), 1.0f);
            }
            ENDCG
        }
    }
}