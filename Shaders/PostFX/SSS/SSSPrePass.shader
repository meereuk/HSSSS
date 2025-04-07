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
        
        ENDCG

        // pass 0 : copy transmission from gbuffer 3 alpha
        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma only_renderers d3d11
            #pragma vertex vert_img
            #pragma fragment frag

            #include "UnityCG.cginc"
            sampler2D _MainTex;
            
            half frag(v2f_img IN) : SV_Target
            {
                return tex2D(_MainTex, IN.uv).a;
            }
            ENDCG
        }
    }
}