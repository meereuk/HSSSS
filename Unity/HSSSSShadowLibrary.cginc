#ifndef HSSSS_SHADOWLIB_CGINC
#define HSSSS_SHADOWLIB_CGINC

#include "Assets/HSSSS/Framework/AreaLight.cginc"
#include "Assets/HSSSS/Unity/ScreenSpaceShadows.cginc"

#if defined(SHADOWS_SCREEN) || defined(SHADOWS_DEPTH)
	uniform Texture2D _CustomShadowMap;
	uniform SamplerState sampler_CustomShadowMap;
#endif

#if defined(SHADOWS_CUBE)
	uniform TextureCube _ShadowMapTexture;
	uniform SamplerState sampler_ShadowMapTexture;
#endif

// cascade weights
inline uint2 GetCascadeIndex(float viewDepth)
{
	float4 weight = float4(viewDepth >= _LightSplitsNear) * float4(viewDepth < _LightSplitsFar);

	uint idx = 3;

	idx = weight.x == 1.0f ? 0 : idx;
	idx = weight.y == 1.0f ? 1 : idx;
	idx = weight.z == 1.0f ? 2 : idx;

	// return current and next cascade
	return uint2(idx, min(idx + 1, 3));
}

// cascade blending
inline float2 GetCascadeWeights(uint cascade, float viewDepth)
{
	float weight = smoothstep(
		lerp(_LightSplitsNear[cascade], _LightSplitsFar[cascade], 0.8f),
		_LightSplitsFar[cascade], viewDepth
	);

	return float2(1.0f - weight, weight);
}

inline float3 GetShadowCoordinate(float3 vec)
{
	float4 wpos = float4(vec, 1.0f);
	float4 coord = mul(unity_World2Shadow[0], wpos);
	return coord.xyz / coord.w;
}

inline float3 GetShadowCoordinate(float3 vec, uint cascade)
{
	float4 wpos = float4(vec, 1.0f);
	float4 coord = mul(unity_World2Shadow[cascade], wpos);
	return coord.xyz;
}

inline float2 PoissonDisk(uint i, uint n)
{
	float t = 2.4f * i;
	float r = sqrt((i + 0.5f) / n);
	return float2(r * cos(t), r * sin(t));
}

#if defined(SHADOWS_CUBE) || defined(SHADOWS_DEPTH) || defined(SHADOWS_SCREEN)
inline float2 SamplePCFShadowMap(float3 vec, float2 uv, float viewDepth, half NdotL)
{
	uint kernelSize = pow(2, clamp(_SoftShadowNumIter, 3, 6));

	// initialize shadow coordinate and depth
	#if defined(SHADOWS_CUBE)
		float pixelDepth = length(vec) * _LightPositionRange.w;
	#elif defined(SHADOWS_DEPTH)
		float pixelDepth = GetShadowCoordinate(vec).z;
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
		float depthScale = 1.0f;
	#elif defined(SHADOWS_SCREEN)
		float depthScale = 1.0f / abs(pixelDepth.x - GetShadowCoordinate(vec - _LightDir.xyz, cascade.x).z);
	#endif

	// slope-based bias
	#if defined(SHADOWS_CUBE)
		pixelDepth = pixelDepth * lerp(0.99f, 1.0f, NdotL);
	#elif defined(SHADOWS_DEPTH)
		pixelDepth = GetShadowCoordinate(vec - lerp(0.001f * _LightDir.xyz, 0.0f, NdotL)).z;
	#elif defined(SHADOWS_SCREEN)
	#endif

	// r: shadow, g: mean z-diff.
	half2 shadow = {0.0h, 0.0h};

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
		for (uint i = 0; i < kernelSize; i ++)
		{
			float3 disk = mul(PoissonDisk(i, kernelSize), tbn);
			float3 sampleCoord = mad(disk, radius.x, vec);

			#if defined(SHADOWS_CUBE)
				float sampleDepth = _ShadowMapTexture.Sample(sampler_ShadowMapTexture, sampleCoord).x;
			#elif defined(SHADOWS_DEPTH)
				float sampleDepth = _CustomShadowMap.Sample(sampler_CustomShadowMap, GetShadowCoordinate(sampleCoord).xy).x;
			#elif defined(SHADOWS_SCREEN)
				float sampleDepth = _CustomShadowMap.Sample(sampler_CustomShadowMap, GetShadowCoordinate(sampleCoord, cascade.x).xy).x;
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
		// thicc-fucking-thickness
		shadow.g = 100.0h;
	#endif

	/////////////////////////////////
	// percentage closer filtering //
	/////////////////////////////////

	#if defined(SHADOWS_SCREEN)
		float2 cascadeWeight = GetCascadeWeights(cascade.x, viewDepth);
	#endif

	[unroll]
	for (uint j = 0; j < kernelSize; j ++)
	{
		float3 disk = mul(PoissonDisk(j, kernelSize), tbn);
		float3 sampleCoord = mad(disk, penumbra, vec);

		#if defined(SHADOWS_CUBE)
			shadow.r += step(pixelDepth, _ShadowMapTexture.Sample(sampler_ShadowMapTexture, sampleCoord).x);
		#elif defined(SHADOWS_DEPTH)
			shadow.r += step(pixelDepth, _CustomShadowMap.Sample(sampler_CustomShadowMap, GetShadowCoordinate(sampleCoord).xy).x);
		#elif defined(SHADOWS_SCREEN)
			shadow.r += step(pixelDepth.x, _CustomShadowMap.Sample(sampler_CustomShadowMap, GetShadowCoordinate(sampleCoord, cascade.x).xy).x);
		/*
			// cascade blending
			half2 cshadow = {
				step(pixelDepth.x, _CustomShadowMap.Sample(sampler_CustomShadowMap, GetShadowCoordinate(sampleCoord, cascade.x).xy).x),
				step(pixelDepth.y, _CustomShadowMap.Sample(sampler_CustomShadowMap, GetShadowCoordinate(sampleCoord, cascade.y).xy).x)
			};
			shadow.r += dot(cshadow, cascadeWeight);
		*/
		#endif
	}

	shadow.r = shadow.r / kernelSize;
	shadow.r = lerp(shadow.r, 1.0h, _LightShadowData.r);
	return shadow;
}
#endif

#endif