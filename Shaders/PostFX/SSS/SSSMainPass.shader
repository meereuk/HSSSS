Shader "Hidden/HSSSS/SSSMainPass"
{
    Properties
    {
        _MainTex ("Render Input", 2D) = "white" {}
    }

    SubShader
    {
        ZTest Always Cull Off ZWrite Off Fog { Mode Off }

        CGINCLUDE
        #pragma target 5.0
        #pragma only_renderers d3d11

        static const half3x3 DecodeRGB = {
            {  1.0h,  1.0h, -1.0h },
            {  1.0h,  0.0h,  1.0h },
            {  1.0h, -1.0h, -1.0h },
        };

        half filter(half2 c, half4x2 a)
        {
            half4 luma = {a[0].x, a[1].x, a[2].x, a[3].x};
            half4 w = 1.0h - step(0.125h, abs(luma - c.x));
            half W = w.x + w.y + w.z + w.w;

            w.x = (W == 0) ? 1 : w.x;
			W = (W == 0) ? 1 : W;

			return (w.x * a[0].y + w.y* a[1].y + w.z* a[2].y + w.w * a[3].y) / W;
        }
        ENDCG
        
        // pass 0 : calculate diffuse light
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityDeferredLibrary.cginc"
            #include "Assets/HSSSS/Framework/Utility.cginc"

            uniform Texture2D _CameraGBufferTexture0;
            uniform Texture2D _CameraGBufferTexture2;
            uniform Texture2D _CameraGBufferTexture3;

            uniform SamplerState sampler_CameraGBufferTexture0;
            uniform SamplerState sampler_CameraGBufferTexture2;
            uniform SamplerState sampler_CameraGBufferTexture3;
            
            half4 frag(v2f_img IN) : SV_Target
            {
                half4 gbuffer0 = _CameraGBufferTexture0.Sample(sampler_CameraGBufferTexture0, IN.uv);
                half4 gbuffer2 = _CameraGBufferTexture2.Sample(sampler_CameraGBufferTexture2, IN.uv);
                half4 gbuffer3 = _CameraGBufferTexture3.Sample(sampler_CameraGBufferTexture3, IN.uv);

                return gbuffer2.w > 0.0h ? 0.0h : half4(gbuffer3.xyz, 1.0h);
            }
            ENDCG
        }

        // pass 1 : diffuse blur in x-axis
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag

            #include "Common.cginc"
            
            half4 frag(v2f_img IN) : SV_Target
            {
                return DiffuseBlur(IN, RandomAxis(IN).xy);
            }
            ENDCG
        }
        

        // pass 2 : diffuse blur in y-axis
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag

            #include "Common.cginc"

            half4 frag(v2f_img IN) : SV_Target
            {
                return DiffuseBlur(IN, RandomAxis(IN).yx * float2(1.0f, -1.0f));
            }
            ENDCG
        }

        // pass 3 : final collect pass
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityDeferredLibrary.cginc"
            #include "Assets/HSSSS/Framework/Utility.cginc"

            uniform Texture2D _MainTex;
            uniform Texture2D _CameraGBufferTexture0;
            uniform Texture2D _CameraGBufferTexture2;
            uniform Texture2D _CameraGBufferTexture3;
            uniform Texture2D _CameraReflectionsTexture;

            /*
            uniform sampler2D _SpecularBufferR : register(s1);
            uniform sampler2D _SpecularBufferG : register(s2);
            uniform sampler2D _SpecularBufferB : register(s3);
            */

            uniform RWTexture2D<float> _SpecularBufferR : register(u1);
            uniform RWTexture2D<float> _SpecularBufferG : register(u2);
            uniform RWTexture2D<float> _SpecularBufferB : register(u3);

            uniform SamplerState sampler_MainTex;
            uniform SamplerState sampler_CameraGBufferTexture0;
            uniform SamplerState sampler_CameraGBufferTexture2;
            uniform SamplerState sampler_CameraGBufferTexture3;
            uniform SamplerState sampler_CameraReflectionsTexture;

            half4 frag(v2f_img IN) : SV_Target
            {
                half4 gbuffer0 = _CameraGBufferTexture0.Sample(sampler_CameraGBufferTexture0, IN.uv);
                half4 gbuffer2 = _CameraGBufferTexture2.Sample(sampler_CameraGBufferTexture2, IN.uv);
                half4 gbuffer3 = _CameraGBufferTexture3.Sample(sampler_CameraGBufferTexture3, IN.uv);
                half3 ambient = _CameraReflectionsTexture.Sample(sampler_CameraReflectionsTexture, IN.uv);

                if (gbuffer2.w > 0.0h)
                {
                    return half4(gbuffer3.xyz + ambient, 1.0h);
                }
                
                else
                {
                    uint2 coord = IN.uv * _ScreenParams.xy;

                    half3 diffuse = _MainTex.Sample(sampler_MainTex, IN.uv);
                    half3 specular = half3(_SpecularBufferR[coord], _SpecularBufferG[coord], _SpecularBufferB[coord]);

                    return half4(diffuse + specular + ambient, 1.0h);
                }

                /*
                if (gbuffer2.w > 0.0h)
                {
                    return half4(gbuffer3.xyz + ambient, 1.0h);
                }

                else
                {
                    half4x2 a = {
                        _CameraGBufferTexture3.Sample(sampler_CameraGBufferTexture3, IN.uv, int2(-1,  0)).zw,
                        _CameraGBufferTexture3.Sample(sampler_CameraGBufferTexture3, IN.uv, int2( 1,  0)).zw,
                        _CameraGBufferTexture3.Sample(sampler_CameraGBufferTexture3, IN.uv, int2( 0, -1)).zw,
                        _CameraGBufferTexture3.Sample(sampler_CameraGBufferTexture3, IN.uv, int2( 0,  1)).zw
                    };

                    half3 diffuse = _MainTex.Sample(sampler_MainTex, IN.uv);

                    half3 specular;
                    specular.xy = gbuffer3.zw;
                    specular.z = filter(specular.xy, a);

                    uint2 coord = IN.uv * _ScreenParams.xy;
                    bool pattern = (coord.x & 1) == (coord.y & 1);

                    specular.xyz = pattern ? specular.xyz : specular.xzy;

                    return half4(mul(DecodeRGB, specular) + diffuse + ambient, 1.0h);
                }
                */
            }
            ENDCG
        }

        // pass 4 : normal blur in x-axis
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag

            #include "Common.cginc"
            
            fixed4 frag(v2f_img IN) : SV_Target
            {
                fixed4 normal = tex2D(_CameraGBufferTexture2, IN.uv);

                if (normal.w < 0.1h)
                {
                    normal = NormalBlur(IN, RandomAxis(IN).xy);
                }

                return normal;
            }
            ENDCG
        }

        // pass 5 : normal blur in y-axis
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag

            #include "Common.cginc"

            fixed4 frag(v2f_img IN) : SV_Target
            {
                fixed4 normal = tex2D(_CameraGBufferTexture2, IN.uv);

                if (normal.w < 0.1h)
                {
                    normal = NormalBlur(IN, RandomAxis(IN).yx * float2(1.0f, -1.0f));
                }

                return normal;
            }
            ENDCG
        }
    }
}