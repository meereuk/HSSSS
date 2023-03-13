﻿Shader "Hidden/HSSSS/ScreenSpaceDiffuseBlur"
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
        #pragma exclude_renderers gles
    
        ENDCG
        
        // subtract ambient reflections
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityDeferredLibrary.cginc"

            sampler2D _MainTex;
            sampler2D _CameraReflectionsTexture;
            
            half4 frag(v2f_img IN) : COLOR
            {
                half4 direct = tex2D(_MainTex, IN.uv);
                half4 ambient = tex2D(_CameraReflectionsTexture, IN.uv);
                direct.rgb = direct.rgb - ambient.rgb;
                return direct;
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
            sampler2D _CameraGBufferTexture2;
            
            half4 frag(v2f_img IN) : COLOR
            {
                half mask = tex2D(_CameraGBufferTexture2, IN.uv).a;
                clip(0.99h - mask);
                float2 axis = RandomAxis(IN.uv).xy;
                return BlurInDir(IN, axis, mask == 0.0h);
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
            sampler2D _CameraGBufferTexture2;

            half4 frag(v2f_img IN) : COLOR
            {
                half mask = tex2D(_CameraGBufferTexture2, IN.uv).a;
                clip(0.99h - mask);
                float2 axis = RandomAxis(IN.uv).yx * float2(1.0f, -1.0f);
                return BlurInDir(IN, axis, mask == 0.0h);
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

            sampler2D _MainTex;
            sampler2D _AmbientDiffuseBuffer;
            sampler2D _CameraGBufferTexture0;
            sampler2D _CameraGBufferTexture2;
            sampler2D _CameraGBufferTexture3;
            sampler2D _CameraReflectionsTexture;
            
            half4 frag(v2f_img IN) : COLOR
            {
                half4 gbuffer0 = tex2D(_CameraGBufferTexture0, IN.uv);
                half4 gbuffer2 = tex2D(_CameraGBufferTexture2, IN.uv);
                half4 gbuffer3 = tex2D(_CameraGBufferTexture3, IN.uv);

                half4 ambientSpecular = tex2D(_CameraReflectionsTexture, IN.uv);
                half4 ambientDiffuse = tex2D(_AmbientDiffuseBuffer, IN.uv);

                if (gbuffer2.a == 1.0h)
                {
                    return gbuffer3;
                }

                else
                {
                    half4 result = tex2D(_MainTex, IN.uv);
                    half3 lightColor = max(0.0h, (gbuffer3.rgb - ambientDiffuse.rgb - ambientSpecular.rgb + 0.0001h) / (gbuffer0.rgb + 0.0001h));
                    half luminance = aLuminance(lightColor);

                    lightColor = luminance > 0.0h ? lightColor / luminance : 1.0h;

                    result.rgb = result.rgb + ambientSpecular.rgb + gbuffer3.aaa * lightColor;

                    return result;
                }
            }
            ENDCG
        }
    }
}