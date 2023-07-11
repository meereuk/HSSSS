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
	}
}
