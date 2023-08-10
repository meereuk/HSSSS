#ifndef POSTFX_COMMON_CGINC
#define POSTFX_COMMON_CGINC

#include "UnityCG.cginc"

/*
#define NUM_TAPS 17

const static half4 blurKernel[NUM_TAPS] = {
    half4(0.53634300, 0.624624000, 0.748867000,  0.00000),
    half4(0.00317394, 0.000134823, 3.77269e-05, -2.00000),
    half4(0.01003860, 0.000914679, 0.000275702, -1.53125),
    half4(0.01446090, 0.003172690, 0.001063990, -1.12500),
    half4(0.02163010, 0.007946180, 0.003769910, -0.78125),
    half4(0.03473170, 0.015108500, 0.008719830, -0.50000),
    half4(0.05710560, 0.028743200, 0.017284400, -0.28125),
    half4(0.05824160, 0.065995900, 0.041132900, -0.12500),
    half4(0.03244620, 0.065671800, 0.053282100, -0.03125),
    half4(0.03244620, 0.065671800, 0.053282100,  0.03125),
    half4(0.05824160, 0.065995900, 0.041132900,  0.12500),
    half4(0.05710560, 0.028743200, 0.017284400,  0.28125),
    half4(0.03473170, 0.015108500, 0.008719830,  0.50000),
    half4(0.02163010, 0.007946180, 0.003769910,  0.78125),
    half4(0.01446090, 0.003172690, 0.001063990,  1.12500),
    half4(0.01003860, 0.000914679, 0.000275702,  1.53125),
    half4(0.00317394, 0.000134823, 3.77269e-05,  2.00000),
};
*/

#define NUM_TAPS 11

const static float4 blurKernel[NUM_TAPS] = {
    float4(0.560479, 0.669086, 0.784728, 0),
    float4(0.00471691, 0.000184771, 5.07566e-005, -2),
    float4(0.0192831, 0.00282018, 0.00084214, -1.28),
    float4(0.03639, 0.0130999, 0.00643685, -0.72),
    float4(0.0821904, 0.0358608, 0.0209261, -0.32),
    float4(0.0771802, 0.113491, 0.0793803, -0.08),
    float4(0.0771802, 0.113491, 0.0793803, 0.08),
    float4(0.0821904, 0.0358608, 0.0209261, 0.32),
    float4(0.03639, 0.0130999, 0.00643685, 0.72),
    float4(0.0192831, 0.00282018, 0.00084214, 1.28),
    float4(0.00471691, 0.000184771, 5.07565e-005, 2),
};

uniform sampler2D _MainTex;
uniform sampler2D _SkinJitter;

uniform sampler2D _CameraDepthTexture;
uniform sampler2D _CameraGBufferTexture2;

uniform float4 _MainTex_TexelSize;
uniform float4 _SkinJitter_TexelSize;

uniform half2 _DeferredBlurredNormalsParams;


void SkipIfNonSkin(v2f_img IN)
{
    half mask = tex2D(_CameraGBufferTexture2, IN.uv).a;
    clip(0.01h - mask);
}

half3 BlurInDir(v2f_img IN, half2 direction)
{
	float2 uv = IN.uv;

	half3 colorM = tex2D(_MainTex, uv).rgb;
	half depthM = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));
	
	float scale = _DeferredBlurredNormalsParams.x * unity_CameraProjection._m11 / depthM;
	float2 finalStep = scale * direction * dot(direction, _MainTex_TexelSize.xy);

    half3 colorB = colorM * blurKernel[0].rgb;
	
	[unroll]
	for (uint i = 1; i < NUM_TAPS; i++)
	{
        // sample color
		float2 offsetUv = uv + finalStep * blurKernel[i].a;
		half3 color = tex2D(_MainTex, offsetUv);
        // depth-aware
		half depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, offsetUv));
		half s = min(1.0h, _DeferredBlurredNormalsParams.y * abs(depth - depthM));
        // mask-aware
        half m = step(0.01h, tex2D(_CameraGBufferTexture2, offsetUv).a);
        // blur
        colorB += lerp(lerp(color, colorM, s), colorM, m) * blurKernel[i].rgb;
	}
        
	return colorB;
}

inline half2 RandomAxis(v2f_img IN)
{
    return tex2D(_SkinJitter, IN.uv * _ScreenParams.xy * _SkinJitter_TexelSize.xy + frac(_Time.yy)).rg;
}

#endif