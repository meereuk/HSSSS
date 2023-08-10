Shader "Hidden/HSSSS/ScreenSpaceDiffuseBlur"
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
        
        // calculate specular light
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityDeferredLibrary.cginc"
            #include "Assets/HSSSS/Framework/Utility.cginc"

            uniform sampler2D _AmbientDiffuseBuffer;
            uniform sampler2D _CameraGBufferTexture0;
            uniform sampler2D _CameraGBufferTexture2;
            uniform sampler2D _CameraGBufferTexture3;
            uniform sampler2D _CameraReflectionsTexture;
            
            half4 frag(v2f_img IN) : SV_Target
            {
                half4 albedo = tex2D(_CameraGBufferTexture0, IN.uv);
                half4 direct = tex2D(_CameraGBufferTexture3, IN.uv);
                half4 ambient = tex2D(_AmbientDiffuseBuffer, IN.uv);
                half mask = tex2D(_CameraGBufferTexture2, IN.uv).w;

                half3 color = 0.0h;

                if (mask < 0.1h)
                {
                    color = (direct.rgb - ambient.rgb) * albedo.rgb + ambient.rgb;
                    color = max(color, half3(0.0h, 0.0h, 0.0h));
                }

                else
                {
                    color = 0.0h;
                }

                return half4(color, 0.0h);
            }
            ENDCG
        }

        // blur in x-axis
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag

            #include "Common.cginc"
            
            half4 frag(v2f_img IN) : SV_Target
            {
                half mask = tex2D(_CameraGBufferTexture2, IN.uv).w;
                half3 color = 0.0h;

                if (mask < 0.1h)
                {
                    color = BlurInDir(IN, RandomAxis(IN).xy);
                }

                else
                {
                    color = 0.0h;
                }

                return half4(color, 0.0h);
            }
            ENDCG
        }
        

        // blur in y-axis
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag

            #include "Common.cginc"

            half4 frag(v2f_img IN) : SV_Target
            {
                half mask = tex2D(_CameraGBufferTexture2, IN.uv).w;
                half3 color = 0.0h;

                if (mask < 0.1h)
                {
                    color = BlurInDir(IN, RandomAxis(IN).yx * float2(1.0f, -1.0f));
                }

                else
                {
                    color = 0.0h;
                }

                return half4(color, 0.0h);
            }
            ENDCG
        }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityDeferredLibrary.cginc"
            #include "Assets/HSSSS/Framework/Utility.cginc"

            uniform sampler2D _MainTex;
            uniform sampler2D _AmbientDiffuseBuffer;
            uniform sampler2D _CameraGBufferTexture0;
            uniform sampler2D _CameraGBufferTexture2;
            uniform sampler2D _CameraGBufferTexture3;
            uniform sampler2D _CameraReflectionsTexture;
            
            half4 frag(v2f_img IN) : SV_Target
            {
                half4 gbuffer0 = tex2D(_CameraGBufferTexture0, IN.uv);
                half4 gbuffer2 = tex2D(_CameraGBufferTexture2, IN.uv);
                half4 gbuffer3 = tex2D(_CameraGBufferTexture3, IN.uv);

                half3 ambientDiffuse = tex2D(_AmbientDiffuseBuffer, IN.uv);
                half3 ambientSpecular = tex2D(_CameraReflectionsTexture, IN.uv);

                half3 result = 0.0h;

                if (gbuffer2.a < 0.1h)
                {
                    half3 lightColor = max(0.0h, gbuffer3.rgb - ambientDiffuse);
                    lightColor = lightColor / max(aLuminance(lightColor), 0.01h);

                    result += tex2D(_MainTex, IN.uv);
                    result += gbuffer3.aaa * lightColor;
                }

                else
                {
                    result = gbuffer3.rgb;
                }

                return half4(result + ambientSpecular, 0.0h);
            }
            ENDCG
        }
    }
}