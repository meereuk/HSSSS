#ifndef HSSSS_CONTACTSHADOW_CGINC
#define HSSSS_CONTACTSHADOW_CGINC

#include "Assets/HSSSS/Framework/AreaLight.cginc"

uniform float4 _CameraDepthTexture_TexelSize;

uniform float _SSCSRayLength;
uniform float _SSCSMeanDepth;
uniform float _SSCSDepthBias;
uniform uint  _SSCSRayStride;

struct ray
{
	// surface uv
	float2 uv0;
	// delta uv
	float2 uv1;
	// surface z
	float z0;
	// delta z
	float z1;
	// bias
	float bias;
};

inline half HorizonTrace(ray ray)
{
	float step = pow(2.0, clamp(_SSCSRayStride, 4, 7));

	float2 duv = ray.uv1 - ray.uv0;
	float slope = duv.y / duv.x;
	float minStr = min(length(_CameraDepthTexture_TexelSize.xx * float2(1.0f, slope)), length(_CameraDepthTexture_TexelSize.yy * float2(1.0f / slope, 1.0f)));
	minStr /= length(duv);

	half shadow = 1.0h;
	float str = 0.0f;

	for (float iter = 1.0f; iter <= step; iter += 1.0f)
	{
		str = max(str + minStr, pow(iter / step, 2));

		float2 uv = lerp(ray.uv0, ray.uv1, str);
		float2 z = lerp(ray.z0, ray.z1, str);

		float fz = LinearEyeDepth(tex2D(_CameraDepthTexture, uv));
		float bz = fz + _SSCSMeanDepth;

		shadow = min(shadow, max(smoothstep(z - ray.bias, z, fz), smoothstep(bz - ray.bias, bz, z)));
	}

	return shadow;
}

inline void ComputeScreenSpaceShadow(float3 wpos, float3 wdir, float2 uv, inout half2 shadow)
{
#if defined(SHADOWS_CUBE) || defined(SHADOWS_DEPTH) || defined(SHADOWS_SCREEN)
	float rayrad = 0.0f;
	float raylen = _SSCSRayLength * 0.01f;

	#if defined(_PCF_ON)
		#if defined(SHADOWS_CUBE)
			rayrad = _PointLightPenumbra.z * length(wdir);
		#elif defined(SHADOWS_DEPTH)
			rayrad = _SpotLightPenumbra.z * length(wdir);
		#elif defined(SHADOWS_SCREEN)
			rayrad = _DirLightPenumbra.z;
		#endif
		rayrad *= 0.01f;
	#elif defined(_PCSS_ON)
		#if defined(SHADOWS_CUBE)
			rayrad = _PointLightPenumbra.y;
		#elif defined(SHADOWS_DEPTH)
			rayrad = _SpotLightPenumbra.y;
		#elif defined(SHADOWS_SCREEN)
			rayrad = _DirLightPenumbra.y;
		#endif
		rayrad *= 0.01f;
	#endif

	float3 jitter = SampleNoise(uv);

	float4 vpos = mul(UNITY_MATRIX_V, float4(wpos, 1.0f));
	float4 vdir = mul(UNITY_MATRIX_V, float4(wdir, 0.0f));
	float4 ddir = mad(jitter.x, 2.0f, -1.0f) * normalize(float4(-vdir.y, vdir.x, 0.0f, 0.0f)) + mad(jitter.y, 2.0f, -1.0f) * float4(0.0f, 0.0f, 1.0f, 0.0f);
	ddir *= rayrad;

	float bias = _SSCSDepthBias * 0.01f;

	half s = 0.0h;

	for (uint iter = 0; iter < 4; iter ++)
	{
		float fuck = (float) iter / 1.5f - 1.0f;

		float4 lp = mad(normalize(mad(ddir, fuck, vdir)), raylen, vpos);
		float4 sp = ComputeScreenPos(mul(UNITY_MATRIX_P, lp));

		ray ray;

		ray.uv0 = uv;
		ray.uv1 = sp.xy / sp.w;
		ray.z0 = -vpos.z;
		ray.z1 = -lp.z;
		ray.bias = bias;

		s += HorizonTrace(ray);
	}

	s /= 4.0h;

	shadow.r = min(shadow.r, lerp(s, 1.0h, _LightShadowData.r));
#endif
}

#endif