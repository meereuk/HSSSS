Shader "Hidden/VSM"
{
	Properties
	{
		_MainTex ("", 2D) = "white" {}
		_ShadowJitter ("", 2D) = "white" {}
		_Penumbra ("", float) = 1.0
	}
	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		CGINCLUDE
		#define NUM_TAPS 17
		
		const static float blurWeights[NUM_TAPS] = {
			0.197416f,
			0.000078f, 0.000489f, 0.002403f, 0.009245f, 0.027835f, 0.065592f, 0.120980f, 0.174670f,
			0.000078f, 0.000489f, 0.002403f, 0.009245f, 0.027835f, 0.065592f, 0.120980f, 0.174670f
		};

		const static float blurOffsets[NUM_TAPS] = {
			0.0f,
			-4.0f, -3.5f, -3.0f, -2.5f, -2.0f, -1.5f, -1.0f, -0.5f,
			+4.0f, +3.5f, +3.0f, +2.5f, +2.0f, +1.5f, +1.0f, +0.5f
    	};

		ENDCG

		// Sampling Squared Depth
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			#include "Common.cginc"

			float4 frag (v2f i) : SV_Target
			{
				float depth = tex2D(_MainTex, i.uv).r;
				//float positive = exp(50.0f * (depth - 1.0f));
				//float negative = exp(-50.0f * depth);
				return float4(depth, depth * depth, 0.0f, 0.0f);
				//return float4(positive, positive * positive, negative, negative * negative);
			}
			ENDCG
		}

		// Blur in x-Axis
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			#include "Common.cginc"

			float _Penumbra;

			fixed4 frag (v2f IN) : SV_Target
			{
				float4 depth, depthM;
				depthM = tex2D(_MainTex, IN.uv);
				depthM = depthM * blurWeights[0];

				float penumbra = _Penumbra / 1024.0f;

				UNITY_UNROLL
				for (int i = 1; i < NUM_TAPS; i ++)
				{
					float2 offset = float2(blurOffsets[i], 0.0f) * penumbra;
					depth = tex2D(_MainTex, IN.uv + offset);
					depthM = depthM + depth * blurWeights[i];
				}

				return depthM;
			}
			ENDCG
		}

		// Blur in y-Axis
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			#include "Common.cginc"

			float _Penumbra;

			fixed4 frag (v2f IN) : SV_Target
			{
				float4 depth, depthM;
				depthM = tex2D(_MainTex, IN.uv);
				depthM = depthM * blurWeights[0];

				float penumbra = _Penumbra / 1024.0f;

				UNITY_UNROLL
				for (int i = 1; i < NUM_TAPS; i ++)
				{
					float2 offset = float2(0.0f, blurOffsets[i]) * penumbra;
					depth = tex2D(_MainTex, IN.uv + offset);
					depthM = depthM + depth * blurWeights[i];
				}

				return depthM;
			}
			ENDCG
		}
	}
}
