Shader "Hidden/HSSSS/Deferred Shading"
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
            #pragma only_renderers d3d11
            #pragma vertex vert_deferred
            #pragma fragment frag

            #pragma multi_compile_lightpass
            #pragma multi_compile ___ UNITY_HDR_ON

            // pre-integrated skin options
            #pragma multi_compile ___ _FACEWORKS_TYPE1 _FACEWORKS_TYPE2 _SCREENSPACE_SSS
            // transmission options
            #pragma multi_compile ___ _BAKED_THICKNESS
            // soft shadows options
            #pragma multi_compile ___ _PCF_ON
            // contact shadow
            //#pragma multi_compile ___ _SSCS_ON

            #include "Assets/HSSSS/Lighting/StandardSkin.cginc"
            #include "Assets/HSSSS/Framework/Deferred.cginc"

            #ifdef _SCREENSPACE_SSS
                uniform RWTexture2D<float> _SpecularBufferR : register(u1);
                uniform RWTexture2D<float> _SpecularBufferG : register(u2);
                uniform RWTexture2D<float> _SpecularBufferB : register(u3);
            #endif

            // RGB to YCoCg color space
            static const half3x3 EncodeRGB = {
                { 0.25h,  0.50h,  0.25h },
                { 0.50h,  0.00h, -0.50h },
                {-0.25h,  0.50h, -0.25h }
            };

            half4 CalculateLight (unity_v2f_deferred i)
            {
                ASurface s = aDeferredSurface(i);
                ADirect d = aDeferredDirect(s);

                half3 diffuse = 0.0h;
                half3 specular = 0.0h;

                aDirect(d, s, diffuse, specular);

                diffuse = aHdrClamp(diffuse);
                specular = aHdrClamp(specular);

                #ifdef _SCREENSPACE_SSS
                    if (s.scatteringMask < 1.0h)
                    {
                        return half4(diffuse + specular, 0.0h);
                    }

                    else
                    {
                        uint2 coord = UnityPixelSnap(i.pos);

                        _SpecularBufferR[coord] += specular.r;
                        _SpecularBufferG[coord] += specular.g;
                        _SpecularBufferB[coord] += specular.b;

                        return half4(diffuse, 0.0h);

                        /*
                        diffuse = mul(EncodeRGB, diffuse);
                        specular = mul(EncodeRGB, specular);

                        bool pattern = (coord.x & 1) == (coord.y & 1);
                        return pattern ? half4(diffuse.rg, specular.rg) : half4(diffuse.rb, specular.rb);
                        */
                    }
                #else
                    return half4(diffuse + specular, 1.0h);
                #endif
            }

            #ifdef UNITY_HDR_ON
            half4 frag (unity_v2f_deferred i) : SV_Target
            #else
            fixed4 frag (unity_v2f_deferred i) : SV_Target
            #endif
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
            #pragma only_renderers d3d11
            #pragma vertex vert
            #pragma fragment frag

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
