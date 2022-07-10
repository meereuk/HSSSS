Shader "Hidden/ScreenSpaceBlur"
{
	SubShader
	{
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "Common.cginc"
			
			sampler2D _MainTex;

			fixed4 frag(v2f IN) : SV_Target
			{
				float2 uv = IN.uv.xy;

				half4 result = tex2D(_MainTex, uv);

				return half4(result.rgb - result.aaa, result.a);
			}

			ENDCG
		}
	}
}
