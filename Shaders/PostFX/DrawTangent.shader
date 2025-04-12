Shader "HSSSS/DrawTangent"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
        _Color ("Primary Color", Color) = (1,1,1,1)

        //_Hash ("Hash", Range(0, 1)) = 0
        _Cutoff ("Cutoff", Range(0, 1)) = 0.5
        //_FuzzBias ("FuzzBias", Range(0, 1)) = 0.0
        //_BlueNoise ("BlueNoise", 3D) = "black" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex   : POSITION;
                float2 uv       : TEXCOORD0;
                float4 tangent  : TANGENT;
            };

            struct v2f
            {
                float4 pos      : SV_POSITION;
                float2 uv       : TEXCOORD0;
                float3 tangent  : TEXCOORD1;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
                o.tangent = normalize(v.tangent.xyz);
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex;
            //uint _FrameCount;
            half4 _Color;
            half _Cutoff;
            //half _FuzzBias;
            //half _Hash;

            fixed4 frag(v2f i) : SV_Target
            {
                half alpha = tex2D(_MainTex, i.uv).w * _Color.w;
                clip(alpha - _Cutoff);
                float3 col = i.tangent * 0.5f + 0.5f;
                return fixed4(col, 1.0f);
            }
            ENDCG
        }
    }

    FallBack "Unlit/Color"
}