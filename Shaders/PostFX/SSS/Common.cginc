#ifndef POSTFX_COMMON_CGINC
#define POSTFX_COMMON_CGINC

#include "UnityCG.cginc"

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

half3 BlurInDir(v2f_img IN, float2 direction)
{
	float2 uv = IN.uv;

	half3 colorM = tex2D(_MainTex, uv).rgb;
	half depthM = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));
	
	float scale = _DeferredBlurredNormalsParams.x * unity_CameraProjection._m11 / depthM;
	float2 finalStep = 0.0005f * scale * direction * normalize(_MainTex_TexelSize.xy);

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

fixed4 NormalBlur(v2f_img IN, float2 direction)
{
    float2 uv = IN.uv;

    half depthM = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));
    fixed4 normalM = tex2D(_MainTex, uv);
    normalM.xyz = mad(normalM.xyz, 2.0h, -1.0h);

    float scale = _DeferredBlurredNormalsParams.x * unity_CameraProjection._m11 / depthM;
	float2 finalStep = 0.0005f * scale * direction * normalize(_MainTex_TexelSize.xy);

    fixed3 normalB = normalM.rgb * blurKernel[0].x;

    [unroll]
    for (uint i = 1; i < NUM_TAPS; i++)
    {
        // sample normal
        float2 offsetUv = uv + finalStep * blurKernel[i].w;
        fixed4 normal = tex2D(_MainTex, offsetUv);
        normal.xyz = mad(normal.xyz, 2.0h, -1.0h);
        // depth-aware
        half depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, offsetUv));
        half s = min(1.0h, _DeferredBlurredNormalsParams.y * abs(depth - depthM));
        // mask-aware
        half m = step(0.01h, normal.w);
        normalB += lerp(lerp(normal.xyz, normalM.xyz, s), normalM.xyz, m) * blurKernel[i].x;
    }

    return fixed4(normalize(normalB) * 0.5h + 0.5h, normalM.a);
}

inline half2 RandomAxis(v2f_img IN)
{
    return tex2D(_SkinJitter, IN.uv * _ScreenParams.xy * _SkinJitter_TexelSize.xy + frac(_Time.yy)).rg;
}

#endif