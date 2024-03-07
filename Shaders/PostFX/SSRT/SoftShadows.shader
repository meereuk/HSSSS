Shader "Hidden/HSSSS/SoftShadows"
{
    Properties
    {
        _MainTex ("", any) = "" {}
    }

    CGINCLUDE
    #pragma target 5.0
    #pragma only_renderers d3d11
    #pragma vertex vert_img
    ENDCG

    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always

        // pass 0 : pcf low
        Pass
        {
            CGPROGRAM
            #pragma fragment frag_shadow
            #pragma multi_compile ___ SHADOWS_OFF
            #pragma multi_compile SPOT POINT DIRECTIONAL
            #define PCF_NUM_TAPS 8
            #define PCSS_OFF
            #include "SoftShadows.cginc"
            ENDCG
        }

        // pass 1 : pcf medium
        Pass
        {
            CGPROGRAM
            #pragma fragment frag_shadow
            #pragma multi_compile ___ SHADOWS_OFF
            #pragma multi_compile SPOT POINT DIRECTIONAL
            #define PCF_NUM_TAPS 16
            #define PCSS_OFF
            #include "SoftShadows.cginc"
            ENDCG
        }

        // pass 2 : pcf high
        Pass
        {
            CGPROGRAM
            #pragma fragment frag_shadow
            #pragma multi_compile ___ SHADOWS_OFF
            #pragma multi_compile SPOT POINT DIRECTIONAL
            #define PCF_NUM_TAPS 32
            #define PCSS_OFF
            #include "SoftShadows.cginc"
            ENDCG
        }

        // pass 3 : pcf ultra
        Pass
        {
            CGPROGRAM
            #pragma fragment frag_shadow
            #pragma multi_compile ___ SHADOWS_OFF
            #pragma multi_compile SPOT POINT DIRECTIONAL
            #define PCF_NUM_TAPS 64
            #define PCSS_OFF
            #include "SoftShadows.cginc"
            ENDCG
        }

        // pass 4 pcss low
        Pass
        {
            CGPROGRAM
            #pragma fragment frag_shadow
            #pragma multi_compile ___ SHADOWS_OFF
            #pragma multi_compile SPOT POINT DIRECTIONAL
            #define PCF_NUM_TAPS 8
            #include "SoftShadows.cginc"
            ENDCG
        }

        // pass 5 : pcss medium
        Pass
        {
            CGPROGRAM
            #pragma fragment frag_shadow
            #pragma multi_compile ___ SHADOWS_OFF
            #pragma multi_compile SPOT POINT DIRECTIONAL
            #define PCF_NUM_TAPS 16
            #include "SoftShadows.cginc"
            ENDCG
        }

        // pass 6 : pcss high
        Pass
        {
            CGPROGRAM
            #pragma fragment frag_shadow
            #pragma multi_compile ___ SHADOWS_OFF
            #pragma multi_compile SPOT POINT DIRECTIONAL
            #define PCF_NUM_TAPS 32
            #include "SoftShadows.cginc"
            ENDCG
        }

        // pass 7 : pcss ultra
        Pass
        {
            CGPROGRAM
            #pragma fragment frag_shadow
            #pragma multi_compile ___ SHADOWS_OFF
            #pragma multi_compile SPOT POINT DIRECTIONAL
            #define PCF_NUM_TAPS 64
            #include "SoftShadows.cginc"
            ENDCG
        }

        // pass 8 : uncheckerboarding
        Pass
        {
            CGPROGRAM
            #pragma fragment frag
            #pragma multi_compile ___ SHADOWS_OFF

            #include "SoftShadows.cginc"

            half frag (v2f_img i) : SV_TARGET
            {
            #ifdef SHADOWS_OFF
                return 1.0h;
            #else
                uint2 coord = round((i.uv - 0.5f * TexelSize.xy) * TexelSize.zw);
                if ((coord.x + coord.y) % 2 != _FrameCount % 2) discard;
                coord.x = coord.x / 2;
	            float2 uv = ((float2) coord + 0.5f) * TexelSize.xy;
                return _MainTex.Sample(sampler_MainTex, uv);
            #endif
            }
            ENDCG
        }

        // pass 9 bilinear interpolation
        Pass
        {
            CGPROGRAM
            #pragma fragment frag
            #pragma multi_compile ___ SHADOWS_OFF

            #include "SoftShadows.cginc"

            half frag (v2f_img i) : SV_TARGET
            {
            #ifdef SHADOWS_OFF
                return 1.0h;
            #else
                float2 uv = i.uv.xy;
                uint2 coord = round((uv - 0.5f * TexelSize.xy) * TexelSize.zw);

                half shadow = 1.0h;

                if ((coord.x + coord.y) % 2 != _FrameCount % 2)
                {
                    half4 tex = half4(
                        _MainTex.Sample(sampler_MainTex, uv, int2( 0,  1)).x,
                        _MainTex.Sample(sampler_MainTex, uv, int2( 1,  0)).x,
                        _MainTex.Sample(sampler_MainTex, uv, int2( 0, -1)).x,
                        _MainTex.Sample(sampler_MainTex, uv, int2(-1,  0)).x
                    );

                    shadow = max(min(tex.x, tex.y), min(tex.z, tex.w));
                }

                else
                {
                    shadow = _MainTex.Sample(sampler_MainTex, uv);
                }

                return shadow;
            #endif
            }
            ENDCG
        }
    }
}