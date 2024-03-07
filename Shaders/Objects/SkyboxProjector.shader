Shader "HSSSS/SkyboxProjector"
{
	Properties
	{
		_Color ("Color", Color) = (1,1,1,1)
		_Tex ("Cubemap (HDR)", Cube) = "black" {}
	}

	SubShader
	{
		Tags
		{
			"Queue" = "Geometry"
			"RenderType" = "Opaque"
		}

		LOD 300
		
		Pass
		{
			Name "DEFERRED"
			Tags { "LightMode" = "Deferred" }
			Cull Off

			CGPROGRAM
			#pragma target 5.0
			#pragma only_renderers d3d11

			#pragma multi_compile ___ UNITY_HDR_ON
            #pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
            #pragma multi_compile DIRLIGHTMAP_OFF DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE
            #pragma multi_compile DYNAMICLIGHTMAP_OFF DYNAMICLIGHTMAP_ON

			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float4 texcoord : TEXCOORD;
				float3 normal : NORMAL;
			};

			v2f vert (appdata_base v)
			{
				v2f o;
				o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
				o.texcoord = mul(_Object2World, v.vertex);
				o.normal = v.normal;
				return o;
			}

			samplerCUBE _Tex;
			half4 _Tex_HDR;
			half4 _Color;

			void frag(v2f i,
				out half4 gbuffer0: SV_Target0,
				out half4 gbuffer1: SV_Target1,
				out half4 gbuffer2: SV_Target2,
				out half4 gbuffer3: SV_Target3
				)
			{
				float3 dir = normalize(i.texcoord - _WorldSpaceCameraPos);

				half4 color = texCUBE(_Tex, dir);
				color.xyz = DecodeHDR(color, _Tex_HDR) * _Color.xyz;

				gbuffer0 = half4(0.0h, 0.0h, 0.0h, 1.0h);
				gbuffer1 = half4(0.0h, 0.0h, 0.0h, 0.0h);
				gbuffer2 = half4(mad(i.normal, 0.5h, 0.5h), 1.0h);
				gbuffer3 = color;
			}

			#define UNITY_PASS_DEFERRED
			ENDCG
		}
	}

	FallBack "Diffuse"
}
