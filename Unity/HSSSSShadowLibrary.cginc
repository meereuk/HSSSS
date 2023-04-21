#ifndef HSSSS_SHADOWLIB_CGINC
#define HSSSS_SHADOWLIB_CGINC

#include "Assets/HSSSS/Framework/AreaLight.cginc"
#include "Assets/HSSSS/Unity/ScreenSpaceShadows.cginc"

#if defined(SHADOWS_SCREEN)
	uniform sampler2D _CustomShadowMap;
	uniform float4 _CustomShadowMap_TexelSize;
#endif

#if defined(SHADOWS_DEPTH)
	uniform sampler2D _ShadowMapTexture;
	uniform float4 _ShadowMapTexture_TexelSize;
#endif

#if defined(SHADOWS_CUBE)
	uniform samplerCUBE _ShadowMapTexture;
	uniform float4 _ShadowMapTexture_TexelSize;
#endif

uniform sampler2D _SSGITemporalAOBuffer;
uniform int _SSGIDirectOcclusion;

// random number generator
inline float GradientNoise(float2 uv)
{
    return frac(sin(dot(uv, float2(12.9898, 78.2333))) * 43758.5453123);
}

// gram-schmidt process
inline float3x3 GramSchmidtMatrix(float2 uv, float3 axis)
{
    float3 jitter = float3(
        GradientNoise(mad(uv, 1.3f, _Time.xx)),
        GradientNoise(mad(uv, 1.6f, _Time.xx)),
        GradientNoise(mad(uv, 1.9f, _Time.xx))
    );

    jitter = normalize(mad(jitter, 2.0f, -1.0f));

    float3 tangent = normalize(jitter - axis * dot(jitter, axis));
    float3 bitangent = normalize(cross(axis, tangent));

    return float3x3(tangent, bitangent, axis);
}

// cascade weights
inline uint2 GetCascadeIndex(float viewDepth)
{
	#if defined(SHADOWS_DEPTH)
		return uint2(0, 0);
	#elif defined(SHADOWS_SCREEN)
		float4 weight = float4(viewDepth >= _LightSplitsNear) * float4(viewDepth < _LightSplitsFar);

		uint idx = 3;

		idx = weight.x == 1.0f ? 0 : idx;
		idx = weight.y == 1.0f ? 1 : idx;
		idx = weight.z == 1.0f ? 2 : idx;

		// return current and next cascade
		return uint2(idx, min(idx + 1, 3));
	#endif
}

// cascade blending
inline float2 GetCascadeWeights(uint cascade, float viewDepth)
{
	float weight = smoothstep(
		lerp(_LightSplitsNear[cascade], _LightSplitsFar[cascade], 0.9f),
		_LightSplitsFar[cascade], viewDepth
	);

	return float2(1.0f - weight, weight);
}

inline float3 GetShadowCoordinate(float3 vec, uint cascade)
{
	float4 wpos = float4(vec, 1.0f);
	float4 coord = mul(unity_World2Shadow[cascade], wpos);

	#if defined(SHADOWS_DEPTH)
		return coord.xyz / coord.w;
	#elif defined(SHADOWS_SCREEN)
		return coord.xyz;
	#endif
}

#if defined(SHADOWS_CUBE) || defined(SHADOWS_DEPTH) || defined(SHADOWS_SCREEN)
inline float2 SamplePCFShadowMap(float3 vec, float2 uv, float viewDepth, half NdotL)
{
	// initialize shadow coordinate and depth
	#if defined(SHADOWS_CUBE)
		float pixelDepth = length(vec) * _LightPositionRange.w;
	#elif defined(SHADOWS_DEPTH)
		uint2 cascade = GetCascadeIndex(viewDepth);
		float pixelDepth = GetShadowCoordinate(vec, cascade.x).z;
	#elif defined(SHADOWS_SCREEN)
		uint2 cascade = GetCascadeIndex(viewDepth);
		float2 pixelDepth = float2(GetShadowCoordinate(vec, cascade.x).z, GetShadowCoordinate(vec, cascade.y).z);
	#endif

	// penumbra sliders
	// x: blocker search radius (in cm)
	// y: light source radius (in cm)
	// z: minimum or fixed size penumbra (in mm)
	#if defined(SHADOWS_CUBE)
		float3 radius = float3(0.01f, 0.01f, 0.001f) * _PointLightPenumbra;
	#elif defined(SHADOWS_DEPTH)
		float3 radius = float3(0.01f, 0.01f, 0.001f) * _SpotLightPenumbra;
	#elif defined(SHADOWS_SCREEN)
		float3 radius = float3(0.01f, 0.01f, 0.001f) * _DirLightPenumbra;
	#endif

	// depth scale factor
	#if defined(SHADOWS_CUBE)
		float depthScale = 1.0f / _LightPositionRange.w;
	#elif defined(SHADOWS_DEPTH)
		float depthScale = 1.0f;// / _LightPositionRange.w;
	#elif defined(SHADOWS_SCREEN)
		float depthScale = 1.0f / abs(pixelDepth.x - GetShadowCoordinate(vec - _LightDir.xyz, cascade.x).z);
	#endif

	// slope-based bias
	#if defined(SHADOWS_CUBE)
		pixelDepth = pixelDepth * lerp(0.990f, 1.0f, NdotL) - lerp(0.001f, 0.0f, NdotL) / depthScale;
	#elif defined(SHADOWS_DEPTH)
		pixelDepth = GetShadowCoordinate(vec + lerp(-0.001f * _LightDir.xyz, 0.0f, NdotL), cascade.x).z;
	#elif defined(SHADOWS_SCREEN)
		pixelDepth = pixelDepth - lerp(0.001f, 0.0f, NdotL) / depthScale;
	#endif

	// r: shadow, g: mean z-diff.
	float2 shadow = float2(0.0f, 0.0f);

	// rotated disk
	float3 disk[PCF_NUM_TAPS];

	// gram-schmidt process
	#if defined(SHADOWS_CUBE)
		float3x3 tbn = GramSchmidtMatrix(uv, normalize(vec));
	#elif defined(SHADOWS_DEPTH)
		float3x3 tbn = GramSchmidtMatrix(uv, _LightDir.xyz);
	#elif defined(SHADOWS_SCREEN)
		float3x3 tbn = GramSchmidtMatrix(uv, _LightDir.xyz);
	#endif

	///////////////////////////////////
	// percentage-closer soft shadow //
	///////////////////////////////////

	#if defined(_PCSS_ON)
		float casterCount = 0;
		float casterDepth = 0.0f;

		// blocker search loop
		[unroll]
		for (uint i = 0; i < PCF_NUM_TAPS; i ++)
		{
			disk[i] = mul(poissonDisk[i], tbn);
			float3 sampleCoord = mad(disk[i], radius.x, vec);

			#if defined(SHADOWS_CUBE)
				float sampleDepth = texCUBE(_ShadowMapTexture, sampleCoord);
			#elif defined(SHADOWS_DEPTH)
				float sampleDepth = tex2D(_ShadowMapTexture, GetShadowCoordinate(sampleCoord, cascade.x).xy);
			#elif defined(SHADOWS_SCREEN)
				float sampleDepth = tex2D(_CustomShadowMap, GetShadowCoordinate(sampleCoord, cascade.x).xy);
			#endif

			if (sampleDepth < pixelDepth.x)
			{
				casterCount += 1.0f;
				casterDepth += sampleDepth;
			}
		}

		casterDepth = casterCount > 0.0f ? casterDepth / casterCount : pixelDepth;

		// penumbra size
		#if defined(SHADOWS_SCREEN)
			float penumbra = max(radius.z, radius.y * (pixelDepth.x - casterDepth) * depthScale);
		#elif defined(SHADOWS_CUBE) || defined(SHADOWS_DEPTH)
			float penumbra = max(radius.z, radius.y * (pixelDepth.x - casterDepth) / casterDepth);
		#endif

		// thickness calculation
		shadow.g = max(0.0f, pixelDepth.x - casterDepth) * depthScale;
	#else
		// fixed sized penumbra
		float penumbra = radius.z;
	#endif

	/////////////////////////////////
	// percentage closer filtering //
	/////////////////////////////////

	#if defined(SHADOWS_SCREEN)
		float2 cascadeWeight = GetCascadeWeights(cascade.x, viewDepth);
	#endif

	[unroll]
	for (uint j = 0; j < PCF_NUM_TAPS; j ++)
	{
		#if !defined(_PCSS_ON)
			disk[j] = mul(poissonDisk[j], tbn);
		#endif
		float3 sampleCoord = mad(disk[j], penumbra, vec);

		#if defined(SHADOWS_CUBE)
			shadow.r += texCUBE(_ShadowMapTexture, sampleCoord) > pixelDepth ? 1.0f : 0.0f;
		#elif defined(SHADOWS_DEPTH)
			shadow.r += tex2D(_ShadowMapTexture, GetShadowCoordinate(sampleCoord, cascade.x).xy) > pixelDepth ? 1.0f : 0.0f;
		#elif defined(SHADOWS_SCREEN)
			// cascade blending
			shadow.r += tex2D(_CustomShadowMap, GetShadowCoordinate(sampleCoord, cascade.x).xy) > pixelDepth.x ? cascadeWeight.x : 0.0f;
			shadow.r += tex2D(_CustomShadowMap, GetShadowCoordinate(sampleCoord, cascade.y).xy) > pixelDepth.y ? cascadeWeight.y : 0.0f;
		#endif
	}

	shadow.r = shadow.r / PCF_NUM_TAPS;

	/*
	if (_SSGIDirectOcclusion == 1)
	{
		// Screen Space Direct Occlusion
		half4 ao = tex2D(_SSGITemporalAOBuffer, uv);
		ao.xyz = normalize(mad(ao.xyz, 2.0h, -1.0h));

		half4 angle;

		// incident light appature
		#if defined(SHADOWS_CUBE)
			angle.x = atan(_PointLightPenumbra.y * sqrt(_LightPos.w));
		#elif defined(SHADOWS_DEPTH)
			angle.x = atan(_SpotLightPenumbra.y * sqrt(_LightPos.w));
		#elif defined(SHADOWS_SCREEN)
			angle.x = atan(0.1h * _DirLightPenumbra.y);
		#endif
		// occlusion apature
		angle.y = acos(sqrt(1.0h - ao.w));
		// absolute angle difference
		angle.z = abs(angle.x - angle.y);
		// angle between bentnormal and light vector
		#if defined(SHADOWS_CUBE)
			angle.w = acos(dot(ao.xyz, normalize(-vec)));
		#elif defined(SHADOWS_DEPTH)
			angle.w = acos(dot(ao.xyz, -_LightDir.xyz));
		#elif defined(SHADOWS_SCREEN)
			angle.w = acos(dot(ao.xyz, -_LightDir.xyz));
		#endif

		half intersection = smoothstep(0.0h, 1.0h, 1.0h - saturate((angle.w - angle.z) / (angle.x + angle.y - angle.z)));
		half occlusion = lerp(0.0h, intersection, saturate((angle.y - 0.1h) * 5.0h));

		shadow.r = min(shadow.r, occlusion);
	}
	*/

	shadow.r = lerp(shadow.r, 1.0h, _LightShadowData.r);
	return shadow;
}
#endif

#endif