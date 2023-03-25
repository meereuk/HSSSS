Shader "Hidden/HSSSS/ScreenSpacePathTracing"
{
    Properties
    {
        _MainTex ("MainTex", any) = "" {}
        _SSGITemporalAOBuffer ("AOBuffer", any) = "black" {}
        _SSGITemporalGIBuffer ("GIBuffer", any) = "black" {}
    }

    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always
        
        // pass 0 : indirect occlusion & bent normal (low preset)
        Pass
        {
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert_img
            #pragma fragment IndirectOcclusion
            #define _SSAONumSample 8
            #define _SSAONumStride 2
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 1 : indirect occlusion & bent normal (medium preset)
        Pass
        {
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert_img
            #pragma fragment IndirectOcclusion
            #define _SSAONumSample 8
            #define _SSAONumStride 4
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 2 : indirect occlusion & bent normal (high preset)
        Pass
        {
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert_img
            #pragma fragment IndirectOcclusion
            #define _SSAONumSample 16
            #define _SSAONumStride 4
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 3 : indirect occlusion & bent normal (ultra preset)
        Pass
        {
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert_img
            #pragma fragment IndirectOcclusion
            #define _SSAONumSample 16
            #define _SSAONumStride 8
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 4 : temporal filtering for the occlusion
        Pass
        {
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert_img
            #pragma fragment TemporalFiltering
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 5 : apply AO to GBuffer 0 (for specular)
        Pass
        {
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert_img
            #pragma fragment ApplyOcclusionToGBuffer0
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 6 : apply AO to GBuffer 3 (for ambient diffuse)
        Pass
        {
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert_img
            #pragma fragment ApplyOcclusionToGBuffer3
            #include "SSAO.cginc"
            ENDCG
        }

        // pass 7 : debug ao
        Pass
        {
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert_img
            #pragma fragment frag
            #include "SSAO.cginc"

            half4 frag(v2f_img IN) : SV_TARGET
            {
                return tex2D(_MainTex, IN.uv);
            }
            ENDCG
        }

        // pass 3 : debug ao (normal)
/*
        // pass 2 : ssgi first bounce
        Pass
        {
            CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #pragma target 5.0

                #define NUM_RAYS 1
                #define NUM_STEP 8

                #include "ScreenSpaceGlobalIllumination.cginc"

                half4 frag (v2f IN) : COLOR
                {
                    return ComputeIndirectDiffuse(IN, true);
                }
            ENDCG
        }

        // pass 3 : ssgi second bounce
        Pass
        {
            CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #pragma target 5.0

                #define NUM_RAYS 1
                #define NUM_STEP 32

                #include "ScreenSpaceGlobalIllumination.cginc"

                half4 frag (v2f IN) : COLOR
                {
                    return ComputeIndirectDiffuse(IN, false);
                }
            ENDCG
        }

        // pass 4 : temporal filter
        Pass
        {
            CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                #define NUM_RAYS 16
                #define NUM_STEP 4

                #include "ScreenSpaceGlobalIllumination.cginc"

                half4 frag (v2f IN) : COLOR
                {
                    half4 vpos;
                    half4 wpos;

                    SampleCoordinates(IN, vpos, wpos);
                    half2 uvOld = GetAccumulationUv(wpos);
                    
                    half4 newGI = tex2D(_MainTex, IN.uv);
                    half4 oldGI = tex2D(_SSGITemporalGIBuffer, uvOld);

                    return lerp(newGI, oldGI, 0.9h);
                }
            ENDCG
        }

        // pass 5 : spatio filter
        Pass
        {
            CGPROGRAM
                #pragma vertex vert_img
                #pragma fragment frag

                #include "UnityCG.cginc"

                sampler2D _MainTex;
                half4 _MainTex_TexelSize;

                static const half3 kernel[8] = {
                    { 1.0f,  0.0f, 0.125f},
                    {-1.0f,  0.0f, 0.125f},
                    { 0.0f,  1.0f, 0.125f},
                    { 0.0f, -1.0f, 0.125f},
                    { 1.0f,  1.0f, 0.0625f},
                    {-1.0f,  1.0f, 0.0625f},
                    { 1.0f, -1.0f, 0.0625f},
                    {-1.0f, -1.0f, 0.0625f},
                };

                half4 frag (v2f_img IN) : COLOR
                {
                    half4 color = 0.0h;

                    color += tex2D(_MainTex, IN.uv) * 0.25f;

                    for(int idx = 0; idx < 8; idx ++)
                    {
                        half4 cs = tex2D(_MainTex, IN.uv + _MainTex_TexelSize.xy * kernel[idx].xy) * kernel[idx].z;
                        color += cs;
                    }

                    return color;
                }

            ENDCG
        }

        // pass 6 : collect everything
        Pass
        {
            CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                #define NUM_RAYS 1
                #define NUM_STEP 16

                #include "ScreenSpaceGlobalIllumination.cginc"

                half4 frag (v2f IN) : COLOR
                {
                    return CollectGI(IN);
                }
            ENDCG
        }
*/
    }
}