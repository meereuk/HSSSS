Shader "Hidden/HSSSS/SSSPrePass"
{
    Properties
    {
        _MainTex ("Render Input", 2D) = "white" {}
    }

    SubShader
    {
        ZTest Always Cull Off ZWrite Off Fog { Mode Off }

        CGINCLUDE
        #pragma target 3.0
        #pragma only_renderers d3d11

        #include "UnityCG.cginc"

        sampler2D _MainTex;

        #pragma vertex vert_img
        #pragma fragment frag
        ENDCG

        // pass 0 : copy transmission from gbuffer 3 alpha
        Pass
        {
            CGPROGRAM
            half frag(v2f_img IN) : SV_Target
            {
                return tex2D(_MainTex, IN.uv).a;
            }
            ENDCG
        }

        // pass 1 : remove transmission from gbuffer 3 alpha
        Pass
        {
            CGPROGRAM
            half4 frag(v2f_img IN) : SV_Target
            {   
                return half4(tex2D(_MainTex, IN.uv).rgb, 0.0f);
            }
            ENDCG
        }

        // pass 2 : ambient reflection (pre-integrated sss)
        Pass
        {
            CGPROGRAM
            uniform sampler2D _CameraGBufferTexture3;
            uniform sampler2D _CameraReflectionsTexture;

            half4 frag(v2f_img IN) : SV_Target
            {
                half4 diffuse = tex2D(_CameraGBufferTexture3, IN.uv);
                half3 specular = tex2D(_CameraReflectionsTexture, IN.uv);

                return half4(diffuse.rgb + specular, diffuse.a);
            }
            ENDCG
        }

        // pass 3: ambient diffuse + specular (screen-space sss)
        Pass
        {
            CGPROGRAM
            uniform sampler2D _CameraGBufferTexture0;
            uniform sampler2D _CameraGBufferTexture2;
            uniform sampler2D _CameraGBufferTexture3;

            static const half3x3 EncodeRGB = {
                { 0.25h,  0.50h,  0.25h },
                { 0.50h,  0.00h, -0.50h },
                {-0.25h,  0.50h, -0.25h }
            };

            half4 frag(v2f_img IN) : SV_Target
            {
                half mask = tex2D(_CameraGBufferTexture2, IN.uv).w;
                half3 albedo = tex2D(_CameraGBufferTexture0, IN.uv);
                half3 diffuse = tex2D(_CameraGBufferTexture3, IN.uv);

                if (mask > 0.0h)
                {
                    return half4(diffuse, 0.0h);
                }

                else
                {
                    diffuse = mul(EncodeRGB, diffuse / max(albedo, 0.0001h));

                    uint2 coord = IN.uv * _ScreenParams.xy;
                    bool pattern = (coord.x & 1) == (coord.y & 1);

                    return pattern ? half4(diffuse.rg, 0.0h, 0.0h) : half4(diffuse.rb, 0.0h, 0.0h);
                }
            }
            ENDCG
        }
    }
}