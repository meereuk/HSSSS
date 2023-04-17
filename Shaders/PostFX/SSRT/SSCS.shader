Shader "Hidden/HSSSS/ScreenSpaceContactShadow"
{
	Properties
	{
		_MainTex ("MainTex", any) = "" {}
	}

	CGINCLUDE
		#include "SSCS.cginc"
	ENDCG

	SubShader
	{
		Cull Off
		ZWrite Off
		ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma target 5.0
			#pragma exclude_renderers gles
			#pragma vertex vert_img
			#pragma fragment ContactShadow
			ENDCG
		}

		Pass
		{
			CGPROGRAM
			#pragma target 5.0
			#pragma exclude_renderers gles
			#pragma vertex vert_img
			#pragma fragment frag

			half frag (v2f_img i) : SV_Target
			{
				return BlurInDir(i.uv, half2(1.0h, 0.0h));
			}
			ENDCG
		}

		Pass
		{
			CGPROGRAM
			#pragma target 5.0
			#pragma exclude_renderers gles
			#pragma vertex vert_img
			#pragma fragment frag

			half frag (v2f_img i) : SV_Target
			{
				return BlurInDir(i.uv, half2(0.0h, 1.0h));
			}
			ENDCG
		}
		
		Pass
		{
			CGPROGRAM
			#pragma target 5.0
			#pragma exclude_renderers gles
			#pragma vertex vert_img
			#pragma fragment frag

			half frag (v2f_img i) : SV_Target
			{
				return BlurInDir(i.uv, half2(2.0h, 0.0h));
			}
			ENDCG
		}

		Pass
		{
			CGPROGRAM
			#pragma target 5.0
			#pragma exclude_renderers gles
			#pragma vertex vert_img
			#pragma fragment frag

			half frag (v2f_img i) : SV_Target
			{
				return BlurInDir(i.uv, half2(0.0h, 2.0h));
			}
			ENDCG
		}
	}
}
