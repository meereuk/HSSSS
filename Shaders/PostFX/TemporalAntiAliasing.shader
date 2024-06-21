Shader "Hidden/HSSSS/TemporalAntiAliasing"
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

        uniform Texture2D _MainTex;
        uniform SamplerState sampler_MainTex;
        uniform float4 _MainTex_TexelSize;

        uniform Texture2D _FrameBufferHistory;
        uniform SamplerState sampler_FrameBufferHistory;

        uniform half _TemporalMixFactor;
        uniform uint _FrameCount;

        static const half3x3 EncodeRGB = {
            { 0.25h,  0.50h,  0.25h },
            { 0.50h,  0.00h, -0.50h },
            {-0.25h,  0.50h, -0.25h }
        };

        static const half3x3 DecodeRGB = {
            {  1.0h,  1.0h, -1.0h },
            {  1.0h,  0.0h,  1.0h },
            {  1.0h, -1.0h, -1.0h },
        };
        ENDCG
        
        // pass 0 : just mix frames
        Pass
        {
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert_img
            #pragma fragment frag_img

            half4 frag_img(v2f_img IN) : SV_TARGET
            {
                half3 current = _MainTex.Sample(sampler_MainTex, IN.uv);
                half3 history = _FrameBufferHistory.Sample(sampler_FrameBufferHistory, IN.uv);
                half mix = clamp(_TemporalMixFactor, 0.000h, 0.996h);
                return half4(lerp(current, history, mix), 1.0h);
            }
            ENDCG
        }

        // pass 1 : temporal upscaling
        Pass
        {
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert_img
            #pragma fragment frag_img

            half4 frag_img(v2f_img IN) : SV_TARGET
            {
                half3 current = _MainTex.Sample(sampler_MainTex, IN.uv);
                half3 history = _FrameBufferHistory.Sample(sampler_FrameBufferHistory, IN.uv);
                half mix = clamp(_TemporalMixFactor, 0.0h, 1.0h);

                uint2 coord = round((IN.uv - 0.5f * _MainTex_TexelSize.xy) * _MainTex_TexelSize.zw);
                mix = (coord.x + coord.y) % 2 == _FrameCount % 2 ? 0.0f : mix;

                return half4(lerp(current, history, mix), 1.0h);
            }
            ENDCG
        }
    }
}