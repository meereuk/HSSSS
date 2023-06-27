Shader "Hidden/HSSSS/BlitDepthBuffer"
{
    Properties
    {
        _MainTex ("MainTex", any) = "" {}
    }

    CGINCLUDE
    #pragma target 5.0
    #pragma exclude_renderers gles
    #pragma vertex vert_img
    ENDCG

    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always

        // pass 0 : prepass
        Pass
        {
            CGPROGRAM
            #pragma fragment GBufferPrePass
            #include "SSGI.cginc"
            ENDCG
        }

        // pass 1 : low
        Pass
        {
            CGPROGRAM
            #pragma fragment IndirectDiffuse
            #define _SSGINumSample 2
            #define _SSGINumStride 4
            #include "SSGI.cginc"
            ENDCG
        }
    }
}