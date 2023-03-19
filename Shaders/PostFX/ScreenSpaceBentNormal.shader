Shader "Hidden/ScreenSpaceBentNormal"
{
    Properties
    {
        _MainTex ("_Texture", any) = "" {}
        _ShadowJitterTexture ("_Jitter", any) = "" {}
    }

    CGINCLUDE
        #include "ScreenSpaceBentNormal.cginc"
    ENDCG

    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always

        Pass
        {
            CGPROGRAM
                #pragma vertex vert_img
                #pragma fragment frag
                #pragma target 5.0
                #pragma exclude_renderers d3d11_9x
                #pragma exclude_renderers d3d9

                half4 frag (v2f_img IN) : COLOR
                {
                    return ComputeIndirectOcclusion(IN.uv.xy);
                }
            ENDCG
        }
    }
}