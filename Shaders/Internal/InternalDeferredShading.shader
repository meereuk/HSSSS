Shader "HSSSS/Deferred Shading"
{
    Properties
    {
        _LightTexture0 ("", any) = "" {}
        _LightTextureB0 ("", 2D) = "" {}
        _ShadowMapTexture ("", any) = "" {}
        _SrcBlend ("", Float) = 1
        _DstBlend ("", Float) = 1
    }

    SubShader
    {
        // Pass 1: Lighting pass
        //  LDR case - Lighting encoded into a subtractive ARGB8 buffer
        //  HDR case - Lighting additively blended into floating point buffer
        Pass
        {
            ZWrite Off
            Blend [_SrcBlend] [_DstBlend]

            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert_deferred
            #pragma fragment frag
            #pragma multi_compile_lightpass
            #pragma multi_compile ___ UNITY_HDR_ON

            // soft shadows options
            #pragma multi_compile ___ _PCF_TAPS_8 _PCF_TAPS_16 _PCF_TAPS_32 _PCF_TAPS_64
            #pragma multi_compile ___ _DIR_PCF_ON
            #pragma multi_compile ___ _PCSS_ON
            // pre-integrated skin options
            #pragma multi_compile ___ _FACEWORKS_TYPE1 _FACEWORKS_TYPE2

            #pragma exclude_renderers nomrt

            #include "Assets/HSSSS/Lighting/StandardSkin.cginc"
            #include "Assets/HSSSS/Framework/Deferred.cginc"

            half4 CalculateLight (unity_v2f_deferred i)
            {    
                ASurface s = aDeferredSurface(i);
                ADirect d = aDeferredDirect(s);

                half4 illum = 0.0h;
                illum.rgb = aDirect(d, s);
                return aHdrClamp(illum);
            }

            #ifdef UNITY_HDR_ON
            half4
            #else
            fixed4
            #endif
            frag (unity_v2f_deferred i) : SV_Target
            {
                half4 c = CalculateLight(i);
                #ifdef UNITY_HDR_ON
                return c;
                #else
                return exp2(-c);
                #endif
            }

            ENDCG
        }

        // Pass 2: Final decode pass.
        // Used only with HDR off, to decode the logarithmic buffer into the main RT
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            Stencil
            {
                ref [_StencilNonBackground]
                readmask [_StencilNonBackground]
                // Normally just comp would be sufficient, but there's a bug and only front face stencil state is set (case 583207)
                compback equal
                compfront equal
            }

            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma exclude_renderers nomrt

            sampler2D _LightBuffer;
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 texcoord : TEXCOORD0;
            };

            v2f vert (float4 vertex : POSITION, float2 texcoord : TEXCOORD0)
            {
                v2f o;
                o.vertex = mul(UNITY_MATRIX_MVP, vertex);
                o.texcoord = texcoord.xy;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return -log2(tex2D(_LightBuffer, i.texcoord));
            }
            ENDCG 
        }
    }

Fallback Off
}
