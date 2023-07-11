#ifndef HSSSS_CONTACTSHADOW_CGINC
#define HSSSS_CONTACTSHADOW_CGINC

#include "Assets/HSSSS/Framework/AreaLight.cginc"

uniform float _SSCSRayLength;
uniform float _SSCSMeanDepth;
uniform float _SSCSDepthBias;
uniform uint  _SSCSRayStride;

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

	float3 jitter = tex2D(_ShadowJitterTexture, uv * _ShadowJitterTexture_TexelSize.xy * _ScreenParams.xy);

	float4 vpos = mul(UNITY_MATRIX_V, float4(wpos, 1.0f));
	float4 vdir = mul(UNITY_MATRIX_V, float4(wdir, 0.0f));
	float4 ddir = mad(jitter.x, 2.0f, -1.0f) * normalize(float4(-vdir.y, vdir.x, 0.0f, 0.0f)) + mad(jitter.y, 2.0f, -1.0f) * float4(0.0f, 0.0f, 1.0f, 0.0f);

	ddir *= rayrad;

	float4 lp0 = mad(normalize(vdir + ddir), raylen, vpos);
	float4 lp1 = mad(normalize(vdir - ddir), raylen, vpos);

	float4 sp0 = ComputeScreenPos(mul(UNITY_MATRIX_P, lp0));
	float4 sp1 = ComputeScreenPos(mul(UNITY_MATRIX_P, lp1));

	float2 uv0 = sp0.xy / sp0.w;
	float2 uv1 = sp1.xy / sp1.w;

	float bias = _SSCSDepthBias * 0.01f;

	float minStr = length(_ScreenParams.zw - 1.0f) / length(uv0 - uv);

	half2 s = 1.0h;

	float step = pow(2.0, min(max(_SSCSRayStride, 4), 7));

	for (float iter = 1.0f; iter <= step && iter * minStr <= 1.0f; iter += 1.0f)
	{
		float str = iter / step;
		str = max(iter * minStr, str * str);

		float2 uv2 = lerp(uv, uv0, str);
		float2 uv3 = lerp(uv, uv1, str);

		float zz0 = lerp(-vpos.z, -lp0.z, str);
		float zz1 = lerp(-vpos.z, -lp1.z, str);

		float z0 = LinearEyeDepth(tex2D(_CameraDepthTexture, uv2));
		float z1 = LinearEyeDepth(tex2D(_CameraDepthTexture, uv3));

		float b0 = z0 + _SSCSMeanDepth;
		float b1 = z1 + _SSCSMeanDepth;

		s.x = min(s.x, max(smoothstep(zz0 - bias, zz0, z0), smoothstep(b0, b0 + 0.0001f, zz0)));
		s.y = min(s.y, max(smoothstep(zz1 - bias, zz1, z1), smoothstep(b0, b0 + 0.0001f, zz1)));
	}

	shadow.r = min(shadow.r, lerp(dot(s, 0.5h), 1.0h, _LightShadowData.r));
#endif
}

#endif