Shader "Hidden/ScreenSpaceRayTracing"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}

	SubShader
	{
		Cull Off
		ZWrite Off
		ZTest Always

		CGINCLUDE
		#include "ScreenSPaceRayTracing.cginc"
		ENDCG

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			half4 frag (v2f i) : SV_Target
			{
				half3 indirect = ComputeIndirectLight(i.uv);
				half3 ref = tex2D(_MainTex, i.uv);

				return half4(ref + indirect, 1.0f);
			}
			ENDCG
		}
	}
}
