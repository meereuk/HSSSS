#ifndef HSSSS_SHADOWLIB_CGINC
#define HSSSS_SHADOWLIB_CGINC

#include "Assets/HSSSS/Framework/AreaLight.cginc"

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

	/*
	#if defined(SHADOWS_DEPTH)
		float4 coord = mul(unity_World2Shadow[0], wpos);
		return coord.xyz / coord.w;
	#elif defined(SHADOWS_SCREEN)
		float4 coord[4] = {
			mul(unity_World2Shadow[0], wpos),
			mul(unity_World2Shadow[1], wpos),
			mul(unity_World2Shadow[2], wpos),
			mul(unity_World2Shadow[3], wpos)
		};
		float4 weight = GetCascadeWeights(viewDepth);
		return (coord[0] * weight.x + coord[1] * weight.y + coord[2] * weight.z + coord[3] * weight.w).xyz;
	#endif
	*/
}

#if defined(SHADOWS_CUBE) || defined(SHADOWS_DEPTH) || defined(SHADOWS_SCREEN)
inline float2 SamplePCFShadowMap(float3 vec, float2 uv, float viewDepth, half NdotL)
{
	// equatorial axe
	float3 rotationX = normalize(cross(_LightDir.xyz, _LightDir.zxy));
	float3 rotationY = normalize(cross(_LightDir.xyz, rotationX));

	// shadow jittering
	float2 jitter = mad(tex2D(_ShadowJitterTexture, uv * _ScreenParams.xy * _ShadowJitterTexture_TexelSize.xy + _Time.yy).rg, 2.0f, -1.0f);
	float2x2 rotationMatrix = float2x2(float2(jitter.x, -jitter.y), float2(jitter.y, jitter.x));

	// initialize shadow coordinate and depth
	#if defined(SHADOWS_CUBE)
		float3 pixelCoord = vec;
		float pixelDepth = length(vec) * _LightPositionRange.w;
	#elif defined(SHADOWS_DEPTH) || defined(SHADOWS_SCREEN)
		uint2 cascade = GetCascadeIndex(viewDepth);
		float3 pixelCoord = GetShadowCoordinate(vec, cascade.x);
		float pixelDepth = pixelCoord.z;
	#endif

	// penumbra sliders
	// x: blocker search radius (in cm)
	// y: light source radius (in cm)
	// z: minimum or fixed size pnumbra (in mm)
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
	#elif defined(SHADOWS_DEPTH) || defined(SHADOWS_SCREEN)
		float depthScale = 1.0f / (GetShadowCoordinate(vec + _LightDir, cascade.x).z - pixelDepth);
	#endif

	// slope-based bias
	#if defined(SHADOWS_CUBE)
		pixelDepth = pixelDepth * lerp(0.990f, 1.0f, NdotL) - lerp(0.001f, 0.0f, NdotL) / depthScale;
	#elif defined(SHADOWS_DEPTH) || defined(SHADOWS_SCREEN)
		pixelDepth = pixelDepth - lerp(0.001f, 0.0f, NdotL) / depthScale;
	#endif

	// r: shadow, g: mean z-diff.
	float2 shadow = float2(0.0f, 0.0f);

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
			float2 disk = mul(poissonDisk[i], rotationMatrix);
			float3 sampleCoord = mad(rotationX * disk.x + rotationY * disk.y, radius.x, vec);

			#if defined(SHADOWS_CUBE)
				float sampleDepth = texCUBE(_ShadowMapTexture, sampleCoord);
			#elif defined(SHADOWS_DEPTH)
				float sampleDepth = tex2D(_ShadowMapTexture, GetShadowCoordinate(sampleCoord, cascade.x).xy);
			#elif defined(SHADOWS_SCREEN)
				float sampleDepth = tex2D(_CustomShadowMap, GetShadowCoordinate(sampleCoord, cascade.x).xy);
			#endif

			if (sampleDepth < pixelDepth)
			{
				casterCount += 1.0f;
				casterDepth += sampleDepth;
			}
		}

		casterDepth = casterCount > 0.0f ? casterDepth / casterCount : pixelDepth;

		// penumbra size
		#if defined(SHADOWS_SCREEN)
			float penumbra = max(radius.z, radius.y * (pixelDepth - casterDepth) * depthScale);
		#elif defined(SHADOWS_CUBE) || defined(SHADOWS_DEPTH)
			float penumbra = max(radius.z, radius.y * (pixelDepth - casterDepth) / casterDepth);
		#endif

		// thickness calculation
		shadow.g = (pixelDepth - casterDepth) * depthScale;
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
		float2 disk = mul(poissonDisk[j], rotationMatrix);
		float3 sampleCoord = mad(rotationX * disk.x + rotationY * disk.y, penumbra, vec);

		#if defined(SHADOWS_CUBE)
			shadow.r += texCUBE(_ShadowMapTexture, sampleCoord) > pixelDepth ? 1.0f : 0.0f;
		#elif defined(SHADOWS_DEPTH)
			shadow.r += tex2D(_ShadowMapTexture, GetShadowCoordinate(sampleCoord, cascade.x).xy) > pixelDepth ? 1.0f : 0.0f;
		#elif defined(SHADOWS_SCREEN)
			// cascade blending
			shadow.r += tex2D(_CustomShadowMap, GetShadowCoordinate(sampleCoord, cascade.x).xy) > pixelDepth ? cascadeWeight.x : 0.0f;
			shadow.r += tex2D(_CustomShadowMap, GetShadowCoordinate(sampleCoord, cascade.y).xy) > pixelDepth ? cascadeWeight.y : 0.0f;
		#endif
	}

	shadow.r = lerp(shadow.r / PCF_NUM_TAPS, 1.0f, _LightShadowData.r);
	return shadow;

	/////////////////////////////
	// variance shadow mapping //
	/////////////////////////////
	/*
	float2 moment = float2(0.0f, 0.0f);

	[unroll]
	for (uint j = 0; j < PCF_NUM_TAPS; j ++)
	{
		float2 disk = mul(poissonDisk[j], rotationMatrix);
		float3 sampleCoord = mad(rotationX * disk.x + rotationY * disk.y, penumbra, vec);

		#if defined(SHADOWS_CUBE)
			float sampleDepth = texCUBE(_ShadowMapTexture, sampleCoord);
		#elif defined(SHADOWS_DEPTH)
			float sampleDepth = tex2D(_ShadowMapTexture, GetShadowCoordinate(sampleCoord, viewDepth).xy);
		#elif defined(SHADOWS_SCREEN)
			float sampleDepth = tex2D(_CustomShadowMap, GetShadowCoordinate(sampleCoord, viewDepth).xy);
		#endif

		moment.x += sampleDepth;
		moment.y += sampleDepth * sampleDepth;
	}

	moment /= PCF_NUM_TAPS;
	*/
}
#endif

#endif