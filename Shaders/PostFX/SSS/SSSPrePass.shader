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

        // copy transmission from gbuffer 3 alpha
        Pass
        {
            CGPROGRAM
            half frag(v2f_img IN) : SV_Target
            {
                return tex2D(_MainTex, IN.uv).a;
            }
            ENDCG
        }

        // remove transmission from gbuffer 3 alpha
        Pass
        {
            CGPROGRAM
            half4 frag(v2f_img IN) : SV_Target
            {   
                return half4(tex2D(_MainTex, IN.uv).rgb, 0.0f);
            }
            ENDCG
        }

        // ambient reflection
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
    }
}