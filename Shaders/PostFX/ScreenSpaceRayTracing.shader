Shader "Hidden/ScreenSpaceRayTracing"
{
	Properties
	{
		_MainTex ("Texture", any) = "" {}
	}

	CGINCLUDE
		#include "ScreenSpaceRayTracing.cginc"
	ENDCG

	SubShader
	{
		Cull Off
		ZWrite Off
		ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			half4 frag (v2f i) : SV_Target
			{
				return 0.0h;
			}
			ENDCG
		}
		
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			half4 frag (v2f i) : SV_Target
			{
				return half4(tex2D(_MainTex, i.uv).rgb + ComputeIndirectLight(i.uv), 0.0h);
			}
			ENDCG
		}

		Pass
        {
            CGPROGRAM
                #pragma vertex vert_img
                #pragma fragment frag

                half4 frag (v2f_img IN) : COLOR
                {
                    return BlurInDir(IN.uv.xy, float2(1.0f, 0.0f));
                }
            ENDCG
        }

		Pass
        {
            CGPROGRAM
                #pragma vertex vert_img
                #pragma fragment frag

                half4 frag (v2f_img IN) : COLOR
                {
                    return BlurInDir(IN.uv.xy, float2(0.0f, 1.0f));
                }
            ENDCG
        }

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			half4 frag (v2f i) : SV_Target
			{
				return tex2D(_MainTex, i.uv.xy) + tex2D(_CameraGBufferTexture3, i.uv.xy);
			}
			ENDCG
		}
	}
}
