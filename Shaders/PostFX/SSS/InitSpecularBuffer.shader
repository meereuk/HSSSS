Shader "Hidden/HSSSS/InitSpecularBuffer"
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

        #include "UnityCG.cginc"
        #include "UnityDeferredLibrary.cginc"

        RWStructuredBuffer<float4> _SpecularBuffer : register(u1);
        ENDCG

        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag

            half4 frag(v2f_img IN) : SV_Target
            {
                uint2 coord = UnityPixelSnap(IN.pos);
                _SpecularBuffer[coord.x + round(_ScreenParams.x) * coord.y] = 0.0h;
                return 0.0h;
            }
            ENDCG
        }
    }
}