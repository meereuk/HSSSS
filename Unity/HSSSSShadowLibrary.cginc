#ifndef HSSSS_SHADOWLIB_CGINC
// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
#pragma exclude_renderers gles
#define HSSSS_SHADOWLIB_CGINC

#include "Assets/HSSSS/Framework/AreaLight.cginc"

#if defined(_RT_SHADOW_HQ)
	#include "Assets/HSSSS/Unity/ScreenSpaceShadows.cginc"
#endif

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

//sampler2D _BentNormalTexture;

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
	#if defined(SHADOWS_CUBE)
		float3 lightDir = -vec;
	#elif defined(SHADOWS_DEPTH)
		float3 lightDir = normalize(_WorldSpaceLightPos0.xyz - vec);
	#elif defined(SHADOWS_SCREEN)
		float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
	#endif

	// shadow jittering
	float3 jitter = normalize(mad(tex2D(_ShadowJitterTexture, uv * _ScreenParams.xy * _ShadowJitterTexture_TexelSize.xy + _Time.yy), 2.0f, -1.0f));
	// gram-schmidt process
	float3 tangentM = normalize(jitter - lightDir * dot(jitter, lightDir));
	float3 tangentB = normalize(cross(lightDir, tangentM));
	float3x3 tbn = float3x3(tangentM, tangentB, lightDir);

	// initialize shadow coordinate and depth
	#if defined(SHADOWS_CUBE)
		float3 pixelCoord = vec;
		float pixelDepth = length(vec) * _LightPositionRange.w;
	#elif defined(SHADOWS_DEPTH)
		uint2 cascade = GetCascadeIndex(viewDepth);
		float3 pixelCoord = GetShadowCoordinate(vec, cascade.x);
		float pixelDepth = pixelCoord.z;
	#elif defined(SHADOWS_SCREEN)
		uint2 cascade = GetCascadeIndex(viewDepth);
		float2x3 pixelCoord = float2x3(GetShadowCoordinate(vec, cascade.x), GetShadowCoordinate(vec, cascade.y));
		float2 pixelDepth = float2(pixelCoord[0].z, pixelCoord[1].z);
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
		float depthScale = 1.0f / (pixelDepth.x - GetShadowCoordinate(vec + lightDir, cascade.x).z);
	#endif

	// slope-based bias
	#if defined(SHADOWS_CUBE)
		pixelDepth = pixelDepth * lerp(0.990f, 1.0f, NdotL) - lerp(0.001f, 0.0f, NdotL) / depthScale;
	#elif defined(SHADOWS_DEPTH)
		pixelDepth = GetShadowCoordinate(vec + lerp(0.002f * lightDir, 0.0f, NdotL), cascade.x).z;
	#endif

	// r: shadow, g: mean z-diff.
	float2 shadow = float2(0.0f, 0.0f);

	// rotated disk
	float3 disk[PCF_NUM_TAPS];

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

	shadow.r = lerp(shadow.r / PCF_NUM_TAPS, 1.0f, _LightShadowData.r);

	#if defined(_RT_SHADOW_HQ)
		SampleScreenSpaceShadow(uv, shadow);
	#endif

	/*
	#if defined(_RT_SHADOW_HQ)
		//SampleScreenSpaceShadow(uv, lightDir, shadow);
		half4 bentNormal = tex2D(_SSGITemporalAOBuffer, uv);
		bentNormal.rgb = normalize(mad(bentNormal.rgb, 2.0h, - 1.0h));
		half threshold = cos(bentNormal.a * 0.5h * UNITY_PI);

		half contactShadow = 0.0h;

		[unroll]
		for (uint k = 0; k < PCF_NUM_TAPS; k ++)
		{
			float3 sampleCoord = normalize(mad(disk[k], 0.04f, lightDir));
			half bentNdotL = dot(sampleCoord, bentNormal.rgb);
			contactShadow += smoothstep(max(threshold, 0.0h), min(threshold + 0.2h, 1.0h), bentNdotL);
			//saturate(bentNdotL - threshold);// ? 1.0h : 0.0h;
		}

		contactShadow = lerp(contactShadow / PCF_NUM_TAPS, 1.0f, _LightShadowData.r);
		shadow.r = min(shadow.r, contactShadow);
	#endif
	*/

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

	return shadow;
}
#endif

#endif