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

            uniform bool _BlurAlbedoTexture;
            
            half4 frag(v2f_img IN) : SV_Target
            {
                half4 gbuffer0 = _CameraGBufferTexture0.Sample(sampler_CameraGBufferTexture0, IN.uv);
                half4 gbuffer2 = _CameraGBufferTexture2.Sample(sampler_CameraGBufferTexture2, IN.uv);
                half4 gbuffer3 = _CameraGBufferTexture3.Sample(sampler_CameraGBufferTexture3, IN.uv);

                half3 div = _BlurAlbedoTexture ? 1.0h : max(gbuffer0.xyz, 0.0001h);

                return gbuffer2.w > 0.0h ? half4(gbuffer3.xyz, 0.0h) : half4(gbuffer3.xyz / div, 1.0h);
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
            uniform Texture2D _CameraReflectionsTexture;

            uniform RWTexture2D<float> _SpecularBufferR : register(u1);
            uniform RWTexture2D<float> _SpecularBufferG : register(u2);
            uniform RWTexture2D<float> _SpecularBufferB : register(u3);

            uniform SamplerState sampler_MainTex;
            uniform SamplerState sampler_CameraGBufferTexture0;
            uniform SamplerState sampler_CameraReflectionsTexture;

            uniform float4 _MainTex_TexelSize;

            uniform uint _FrameCount;
            uniform bool _BlurAlbedoTexture;

            half4 frag(v2f_img IN) : SV_Target
            {
                half3 albedo = _CameraGBufferTexture0.Sample(sampler_CameraGBufferTexture0, IN.uv);
                half3 ambient = _CameraReflectionsTexture.Sample(sampler_CameraReflectionsTexture, IN.uv);
                half4 color = _MainTex.Sample(sampler_MainTex, IN.uv);

                uint2 coord = round((IN.uv - 0.5f * _MainTex_TexelSize.xy) * _MainTex_TexelSize.zw);
                //uint2 coord = IN.uv * _ScreenParams.xy;

                if (color.w < 1.0h)
                {
                    return half4(color.xyz + ambient, 1.0h);
                }
                
                else
                {
                    half3 specular = half3(_SpecularBufferR[coord], _SpecularBufferG[coord], _SpecularBufferB[coord]);

                    half3 div = _BlurAlbedoTexture ? 1.0h : max(albedo, 0.0001h);

                    return half4(color.xyz * div + specular + ambient, 1.0h);
                }
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
                return NormalBlur(IN, RandomAxis(IN).xy);
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
                return NormalBlur(IN, RandomAxis(IN).yx * float2(1.0f, -1.0f));
            }
            ENDCG
        }

        // pass 6 : checkerboard
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityDeferredLibrary.cginc"

            uniform Texture2D _MainTex;
            uniform SamplerState sampler_MainTex;
            uniform float4 _MainTex_TexelSize;
            uniform uint _FrameCount;

            half4 frag(v2f_img IN) : SV_Target
            {
                uint2 coord = round((IN.uv - 0.5f * _MainTex_TexelSize.xy) * _MainTex_TexelSize.zw);
                half4 color = 0.0h;

                if ((coord.x + coord.y) % 2 != _FrameCount % 2)
                {
                    color += _MainTex.Sample(sampler_MainTex, IN.uv, int2( 0,  1));
                    color += _MainTex.Sample(sampler_MainTex, IN.uv, int2( 0, -1));
                    color += _MainTex.Sample(sampler_MainTex, IN.uv, int2( 1,  0));
                    color += _MainTex.Sample(sampler_MainTex, IN.uv, int2(-1,  0));

                    color /= 4.0h;
                }

                else
                {
                    color = _MainTex.Sample(sampler_MainTex, IN.uv);
                }

                return color;
            }
            ENDCG
        }
    }
}