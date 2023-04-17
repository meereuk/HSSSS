Shader "Hidden/HSSSS/AmbientOcclusion"
{
    Properties
    {
        _MainTex ("MainTex", any) = "" {}
    }

    CGINCLUDE
    #pragma target 3.0
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
            #define _SSAONumSample 4
            #define _SSAONumStride 4
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 1 : hbao medium
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectOcclusion
            #define _SSAONumSample 4
            #define _SSAONumStride 8
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 2 : hbao high
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectOcclusion
            #define _SSAONumSample 4
            #define _SSAONumStride 12
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 3 : hbao ultra
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectOcclusion
            #define _SSAONumSample 4
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
            #define _SSAONumSample 4
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
            #define _SSAONumSample 4
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
            #define _SSAONumSample 4
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
            #define _SSAONumSample 4
            #define _SSAONumStride 16
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 8 : ao to GBuffer 0 (for specular)
        Pass
        {
            CGPROGRAM
            #pragma fragment ApplyOcclusionToGBuffer0
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 9 : ao to GBuffer 3 (for ambient diffuse)
        Pass
        {
            CGPROGRAM
            #pragma fragment ApplyOcclusionToGBuffer3
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 10 : bilateral blur in x
        Pass
        {
            CGPROGRAM
            #pragma fragment BilateralBlur
            #define _BLUR_DIR_X
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 11 : bilateral blur in y
        Pass
        {
            CGPROGRAM
            #pragma fragment BilateralBlur
            #define _BLUR_DIR_Y
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 12 : debug
        Pass
        {
            CGPROGRAM
            #pragma fragment frag
            #include "SSAO.cginc"
            half4 frag(v2f_img IN) : SV_TARGET
            {
                return tex2D(_SSGITemporalAOBuffer, IN.uv).r;
            }
            ENDCG
        }
    }
}