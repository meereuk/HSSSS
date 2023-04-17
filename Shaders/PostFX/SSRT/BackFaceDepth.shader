Shader "Hidden/BackFaceDepth"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Cutoff ("Cutoff", Range(0, 1)) = 0.5
	}

	CGINCLUDE
		#include "UnityCG.cginc"

		sampler2D _MainTex;
		float4 _MainTex_ST;
		float _Cutoff;

		struct appdata
		{
			float2 uv : TEXCOORD0;
			float4 vertex : POSITION;
		};

		struct v2f
		{
			float2 uv : TEXCOORD0;
			float depth : TEXCOORD1;
			float4 vertex : SV_POSITION;
		};

		v2f vert (appdata v)
		{
			v2f o;
			o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
			o.depth = -mul(UNITY_MATRIX_MV, v.vertex).z;
			o.uv = TRANSFORM_TEX(v.uv, _MainTex);
			return o;
		}
	ENDCG


	SubShader
	{
		Tags { "RenderType" = "TransparentCutout" }
		LOD 100

		Pass
		{
			//ZWrite On
			Cull Front
			CGPROGRAM
			#pragma target 5.0
			#pragma only_renderers d3d11
			#pragma vertex vert
			#pragma fragment frag

			float frag(v2f i) : SV_Target
			{
				float alpha = tex2D(_MainTex, i.uv).a;
				if (alpha < _Cutoff) discard;
				return (1.0f / i.depth - _ZBufferParams.w) / _ZBufferParams.z;
			}
			ENDCG
		}
	}
}
