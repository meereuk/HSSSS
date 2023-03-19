﻿Shader "Hidden/HSSSS/ScreenSpaceContactShadow"
{
	Properties
	{
		_MainTex ("MainTex", any) = "" {}
	}

	CGINCLUDE
		#include "ScreenSpaceShadow.cginc"
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
			#pragma vertex vert
			#pragma fragment frag

			half frag (v2f i) : SV_Target
			{
				return SampleShadowMap(i);
			}
			ENDCG
		}
	}
}
