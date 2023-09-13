Shader "Hidden/HSSSS/ScreenSpaceNormalBlur"
{
    Properties
    {
        _MainTex ("Render Input", 2D) = "white" {}
    }

    SubShader
    {
        ZTest Always Cull Off ZWrite Off Fog { Mode Off }

        CGINCLUDE
        #pragma target 5.0
        #pragma only_renderers d3d11
    
        #include "UnityCG.cginc"
        #include "UnityDeferredLibrary.cginc"

        #define NUM_TAPS 11

        const static half2 blurKernel[NUM_TAPS] = {
            half2(0.56047900,  0.00),
            half2(0.00471691, -2.00),
            half2(0.01928310, -1.28),
            half2(0.03639000, -0.72),
            half2(0.08219040, -0.32),
            half2(0.07718020, -0.08),
            half2(0.07718020,  0.08),
            half2(0.08219040,  0.32),
            half2(0.03639000,  0.72),
            half2(0.01928310,  1.28),
            half2(0.00471691,  2.00),
        };

        sampler2D _MainTex;
        sampler2D _SkinJitter;

        half4 _MainTex_TexelSize;
        half4 _SkinJitter_TexelSize;

        half2 _DeferredBlurredNormalsParams;

        inline fixed4 BlurInDir(v2f_img IN, float2 direction)
        {
            half2 uv = IN.uv;

            half depthM = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));
            fixed4 normalM = mad(tex2D(_MainTex, uv), 2.0h, -1.0h);

            clip(0.01 - normalM.a);

            half scale = _DeferredBlurredNormalsParams.x * unity_CameraProjection._m11 / depthM;
            half2 finalStep = 0.0005f * scale * direction * normalize(_MainTex_TexelSize.xy);

            fixed3 normalB = normalM.rgb * blurKernel[0].x;

            [unroll]
            for (uint i = 1; i < NUM_TAPS; i++)
            {
                // sample normal
                half2 offsetUv = uv + finalStep * blurKernel[i].y;
                fixed4 normal = mad(tex2D(_MainTex, offsetUv), 2.0h, -1.0h);
                // depth-aware
                half depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, offsetUv));
                half s = min(1.0h, _DeferredBlurredNormalsParams.y * abs(depth - depthM));
                // mask-aware
                half m = step(0.01h, normal.a);
                normalB += lerp(lerp(normal.rgb, normalM.rgb, s), normalM.rgb, m) * blurKernel[i].x;
            }
        
            return fixed4(normalize(normalB) * 0.5h + 0.5h, normalM.a);
        }

        inline half2 RandomAxis(half2 uv)
        {
            return tex2D(_SkinJitter, uv * _ScreenParams.xy * _SkinJitter_TexelSize.xy + frac(_Time.yy)).rg;
        }
        ENDCG
        
        // blur #1
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag
            
            fixed4 frag(v2f_img IN) : SV_Target
            {
                half2 axis = RandomAxis(IN.uv).xy;
                return BlurInDir(IN, axis);
            }
            ENDCG
        }
        
        // blur #2
        Pass{
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag

            fixed4 frag(v2f_img IN) : SV_Target
            {
                half2 axis = RandomAxis(IN.uv).yx * half2(1.0f, -1.0f);
                return BlurInDir(IN, axis);
            }
            ENDCG
        }
    }
}