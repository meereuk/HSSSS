Shader "Hidden/HSSSS/TemporalBlend"
{
    Properties
    {
        _MainTex ("MainTex", any) = "" {}
    }

    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always

        CGINCLUDE
        #include "UnityCG.cginc"

        sampler2D _MainTex;
        sampler2D _FrameBufferHistory;
        sampler2D _CameraDepthTexture;
        sampler2D _CameraDepthHistory;

        uniform float4x4 _WorldToViewMatrix;
        uniform float4x4 _ViewToWorldMatrix;

        uniform float4x4 _ViewToClipMatrix;
        uniform float4x4 _ClipToViewMatrix;

        uniform float4x4 _PrevWorldToViewMatrix;
        uniform float4x4 _PrevViewToWorldMatrix;

        uniform float4x4 _PrevViewToClipMatrix;
        uniform float4x4 _PrevClipToViewMatrix;

        inline float4 SampleCurrentPosition(float2 uv)
        {
            // screen space position
            float4 spos = float4(uv * 2.0f - 1.0f, 1.0f, 1.0f);
            spos = mul(_ClipToViewMatrix, spos);
            spos = spos / spos.w;
            // normalized linear depth
            float depth = Linear01Depth(tex2D(_CameraDepthTexture, uv));
            // view space position
            float4 vpos = half4(spos.xyz * depth, 1.0h);
            // world space position
            return mul(_ViewToWorldMatrix, vpos);
        }

        inline float4 SampleHistoryPosition(float2 uv)
        {
            // screen space position
            float4 spos = float4(uv * 2.0f - 1.0f, 1.0f, 1.0f);
            spos = mul(_PrevClipToViewMatrix, spos);
            spos = spos / spos.w;
            // normalized linear depth
            float depth = Linear01Depth(tex2D(_CameraDepthHistory, uv));
            // view space position
            float4 vpos = half4(spos.xyz * depth, 1.0h);
            // world space position
            return mul(_PrevViewToWorldMatrix, vpos);
        }

        inline float2 SampleHistoryUV(float4 wpos)
        {
            float4 vpos = mul(_PrevWorldToViewMatrix, wpos);
            float4 spos = mul(_PrevViewToClipMatrix, vpos);
            return mad(spos.xy / spos.w, 0.5h, 0.5h);
        }
        ENDCG

        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert_img
            #pragma fragment frag_img

            float2 frag_img(v2f_img IN) : SV_TARGET
            {
                float2 zHist = tex2D(_CameraDepthHistory, IN.uv);
                zHist.x = zHist.y;
                zHist.y = Linear01Depth(tex2D(_CameraDepthTexture, IN.uv));
                return zHist;
            }
            ENDCG
        }

        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert_img
            #pragma fragment frag_img
            
            half4 frag_img(v2f_img IN) : SV_TARGET
            {
                float2 uvCurrent = IN.uv;
                float4 wpCurrent = SampleCurrentPosition(uvCurrent);

                float2 uvHistory = SampleHistoryUV(wpCurrent);
                float4 wpHistory = SampleHistoryPosition(uvHistory);

                half4 colorCurrent = tex2D(_MainTex, uvCurrent);
                half4 colorHistory = tex2D(_FrameBufferHistory, uvHistory);

                return exp(-distance(wpCurrent.xyz, wpHistory.xyz));

                //return lerp(colorCurrent, colorHistory, s);
            }
            ENDCG
        }
    }
}