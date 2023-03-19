Shader "Hidden/HSSSS/TransmissionBlit"
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
        #pragma exclude_renderers gles

        #include "UnityCG.cginc"

        sampler2D _MainTex;
        ENDCG

        // copy transmission from gbuffer 3 alpha
        Pass
        {
            CGPROGRAM    
            #pragma vertex vert_img
            #pragma fragment frag
            
            half frag(v2f_img IN) : COLOR
            {
                return tex2D(_MainTex, IN.uv).a;
            }
            ENDCG
        }

        // remove transmission from gbuffer 3 alpha
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag
            
            half4 frag(v2f_img IN) : COLOR
            {
                return half4(tex2D(_MainTex, IN.uv).rgb, 0.0f);
            }
            ENDCG
        }
    }
}