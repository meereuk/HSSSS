#ifndef POSTFX_COMMON_CGINC
#define POSTFX_COMMON_CGINC

#include "UnityCG.cginc"
#include "UnityDeferredLibrary.cginc"

#define NUM_TAPS 17

const static float4 blurKernel[NUM_TAPS] = {
    float4(0.536343, 0.624624, 0.748867, 0),
    float4(0.00317394, 0.000134823, 3.77269e-005, -2),
    float4(0.0100386, 0.000914679, 0.000275702, -1.53125),
    float4(0.0144609, 0.00317269, 0.00106399, -1.125),
    float4(0.0216301, 0.00794618, 0.00376991, -0.78125),
    float4(0.0347317, 0.0151085, 0.00871983, -0.5),
    float4(0.0571056, 0.0287432, 0.0172844, -0.28125),
    float4(0.0582416, 0.0659959, 0.0411329, -0.125),
    float4(0.0324462, 0.0656718, 0.0532821, -0.03125),
    float4(0.0324462, 0.0656718, 0.0532821, 0.03125),
    float4(0.0582416, 0.0659959, 0.0411329, 0.125),
    float4(0.0571056, 0.0287432, 0.0172844, 0.28125),
    float4(0.0347317, 0.0151085, 0.00871983, 0.5),
    float4(0.0216301, 0.00794618, 0.00376991, 0.78125),
    float4(0.0144609, 0.00317269, 0.00106399, 1.125),
    float4(0.0100386, 0.000914679, 0.000275702, 1.53125),
    float4(0.00317394, 0.000134823, 3.77269e-005, 2),
};

uniform sampler2D _MainTex;
uniform sampler2D _SkinJitter;

float2 _DeferredBlurredNormalsParams;
float4 _MainTex_TexelSize;
float4 _SkinJitter_TexelSize;

half4 BlurInDir(v2f_img IN, float2 direction)
{
	float2 uv = IN.uv;

	half3 colorM = tex2D(_MainTex, uv).rgb;
	half depthM = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));
	
	float scale = _DeferredBlurredNormalsParams.x * unity_CameraProjection._m11 / depthM;
	float2 finalStep = scale * direction * dot(direction, _MainTex_TexelSize.xy);

    half3 colorB = colorM * blurKernel[0].rgb;
	
	UNITY_UNROLL
	for (int i = 1; i < NUM_TAPS; i++)
	{
		float2 offsetUv = uv + finalStep * blurKernel[i].a;
		half3 color = tex2D(_MainTex, offsetUv);
		half3 depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, offsetUv));
		half3 s = min(1.0f, _DeferredBlurredNormalsParams.y * abs(depth - depthM));

        colorB += lerp(color, colorM, s) * blurKernel[i].rgb;
	}
        
	return half4(colorB, tex2D(_MainTex, uv).a);
}

inline float2 RandomAxis(float2 uv)
{
    return tex2D(_SkinJitter, uv * _ScreenParams.xy * _SkinJitter_TexelSize.xy + frac(_Time.yy)).rg;
}

#endif