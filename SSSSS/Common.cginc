#ifndef VSM_COMMON_CGINC
#define VSM_COMMON_CGINC

struct appdata
{
	float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
};

struct v2f
{
	float2 uv : TEXCOORD0;
	float4 vertex : SV_POSITION;
};

v2f vert (appdata v)
{
	v2f o;
	o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
	o.uv = v.uv;
	return o;
}

#define NUM_TAPS 17
		
const static float blurWeights[NUM_TAPS] =
{
	0.197416f,
	0.000078f, 0.000489f, 0.002403f, 0.009245f, 0.027835f, 0.065592f, 0.120980f, 0.174670f,
	0.000078f, 0.000489f, 0.002403f, 0.009245f, 0.027835f, 0.065592f, 0.120980f, 0.174670f
};

const static float blurOffsets[NUM_TAPS] =
{
	0.0f,
	-4.0f, -3.5f, -3.0f, -2.5f, -2.0f, -1.5f, -1.0f, -0.5f,
	+4.0f, +3.5f, +3.0f, +2.5f, +2.0f, +1.5f, +1.0f, +0.5f
};

#endif