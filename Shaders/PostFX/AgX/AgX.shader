Shader "Hidden/AgXToneMapper"
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

		Pass
		{
			CGPROGRAM
			#pragma vertex vert_img
			#pragma fragment frag
			#define AGX_LOOK 0
			
			#include "UnityCG.cginc"
			#include "AgX.cginc"
			ENDCG
		}

		Pass
		{
			CGPROGRAM
			#pragma vertex vert_img
			#pragma fragment frag
			#define AGX_LOOK 1
			
			#include "UnityCG.cginc"
			#include "AgX.cginc"
			ENDCG
		}

		Pass
		{
			CGPROGRAM
			#pragma vertex vert_img
			#pragma fragment frag
			#define AGX_LOOK 2
			
			#include "UnityCG.cginc"
			#include "AgX.cginc"
			ENDCG
		}
	}
}
