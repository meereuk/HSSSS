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
        #pragma exclude_renderers gles
    
        #include "UnityCG.cginc"
        #include "UnityDeferredLibrary.cginc"

        #define NUM_TAPS 11

        const static float2 blurKernel[NUM_TAPS] = {
            float2(0.560479, 0),
            float2(0.00471691, -2),
            float2(0.0192831, -1.28),
            float2(0.03639, -0.72),
            float2(0.0821904, -0.32),
            float2(0.0771802, -0.08),
            float2(0.0771802, 0.08),
            float2(0.0821904, 0.32),
            float2(0.03639, 0.72),
            float2(0.0192831, 1.28),
            float2(0.00471691, 2),
        };

        const static float blurOffsets[NUM_TAPS] = {
            0.0f, -3.0f, -2.4f, -1.8f, -1.2f, -0.6f, 0.6f, 1.2f, 1.8f, 2.4f, 3.0f
        };

        const static float blurWeights[NUM_TAPS] = {
            0.1986f, 0.0093f, 0.0280f, 0.0660f, 0.1217f, 0.1757f, 0.1757f, 0.1217f, 0.0660f, 0.0280f, 0.0093f
        };

        float2 _DeferredBlurredNormalsParams; 

        sampler2D _MainTex;
        sampler2D _SkinJitter;
        sampler2D _CameraGBufferTexture0;
        sampler2D _CameraGBufferTexture1;
        sampler2D _CameraGBufferTexture2;
        float4 _SkinJitter_TexelSize;
        float4 _CameraGBufferTexture2_TexelSize;

        void FetchSamples(float2 uv, out float3 normal, out float depth)
        {
            float4 sampleUv = float4(uv, 0.0f, 0.0f);
            normal = tex2Dlod(_MainTex, sampleUv).xyz * 2.0f - 1.0f;
            depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_LOD(_CameraDepthTexture, sampleUv));
        }

        float4 BlurInDir(v2f_img IN, float2 direction)
        {
            float3 normalM;
            float depthM;

            FetchSamples(IN.uv.xy, normalM, depthM);

            float scale = _DeferredBlurredNormalsParams.x * unity_CameraProjection._m11 / depthM;
            float2 finalStep = scale * direction * dot(direction, _CameraGBufferTexture2_TexelSize.xy);
            float3 normalBlurred = normalM * blurKernel[0].x;

            UNITY_UNROLL
            for (int i = 1; i < NUM_TAPS; i++)
            {
                float3 normal;
                float depth;

                FetchSamples(IN.uv.xy + finalStep * blurKernel[i].y, normal, depth);
                //FetchSamples(IN.uv.xy + finalStep * blurOffsets[i], normal, depth);
                float s = min(1.0f, _DeferredBlurredNormalsParams.y * abs(depth - depthM));
                normalBlurred += lerp(normal, normalM, s) * blurKernel[i].x;
            }
        
            return float4(normalize(normalBlurred) * 0.5f + 0.5f, 0.0f);
        }

        inline float2 RandomAxis(float2 uv)
        {
            return tex2D(_SkinJitter, uv * _ScreenParams.xy * _SkinJitter_TexelSize.xy + frac(_Time.yy)).rg;
        }
        ENDCG
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag
            
            float4 frag(v2f_img IN) : SV_Target
            {
                float2 axis = RandomAxis(IN.uv).xy;
                return BlurInDir(IN, axis);
            }
            ENDCG
        }
        
        Pass{
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag

            float4 frag(v2f_img IN) : SV_Target
            {
                float2 axis = RandomAxis(IN.uv).yx * float2(1.0f, -1.0f);
                return BlurInDir(IN, axis);
            }
            ENDCG
        }
    }
}