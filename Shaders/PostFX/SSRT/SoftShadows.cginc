#ifndef HSSSS_SOFTSHADOWS_CGINC
#define HSSSS_SOFTSHADOWS_CGINC

#pragma exclude_renderers gles

#include "UnityCG.cginc"
#include "UnityDeferredLibrary.cginc"

#ifndef PCF_NUM_TAPS
	#define PCF_NUM_TAPS 16
#endif

uniform sampler3D _BlueNoise;

#ifndef SHADOWS_OFF
uniform uint _FrameCount;
uniform uint _SparseRendering;

uniform float _SlopeBiasScale;
uniform float3 _DirLightPenumbra;
uniform float3 _SpotLightPenumbra;
uniform float3 _PointLightPenumbra;

uniform float4x4 _WorldToViewMatrix;
uniform float4x4 _ViewToWorldMatrix;
uniform float4x4 _ViewToClipMatrix;
uniform float4x4 _ClipToViewMatrix;
uniform float4x4 _ShadowProjMatrix;

#if defined(POINT)
    uniform samplerCUBE_float _MainTex;
#elif defined(SPOT)
    uniform sampler2D_float _MainTex;
#elif defined(DIRECTIONAL)
    uniform sampler2D_float _CascadeShadowMap;
#else
	uniform Texture2D _MainTex;
	uniform SamplerState sampler_MainTex;
#endif

uniform sampler2D _CameraGBufferTexture2;
uniform float4 _CameraDepthTexture_TexelSize;
#define TexelSize _CameraDepthTexture_TexelSize

// jittering
inline float3 SampleNoise(float2 uv)
{
    float z = (float)(_FrameCount % 64) * 0.015625f + 0.0078125f;
    return tex3D(_BlueNoise, float3(uv * _ScreenParams.xy * 0.0078125f, z));
}

// gram-schmidt process
inline float3x3 GramSchmidtMatrix(float2 uv, float3 axis)
{
    float3 jitter = normalize(mad(SampleNoise(uv), 2.0f, -1.0f));
    float3 tangent = normalize(jitter - axis * dot(jitter, axis));
    float3 bitangent = normalize(cross(axis, tangent));

    return float3x3(tangent, bitangent, axis);
}

// posisson disc sampling
inline float2 PoissonDisc(uint i, uint n)
{
	float t = 2.4f * i;
	float r = sqrt((i + 0.5f) / n);
	return float2(r * cos(t), r * sin(t));
}

inline uint2 GetCascadeIndex(float depth)
{
	float4 weight = float4(depth >= _LightSplitsNear) * float4(depth < _LightSplitsFar);

	uint idx = 3;

	idx = weight.x == 1.0f ? 0 : idx;
	idx = weight.y == 1.0f ? 1 : idx;
	idx = weight.z == 1.0f ? 2 : idx;

	// return current and next cascade
	return uint2(idx, min(idx + 1, 3));
}

inline float3 GetShadowCoordinate(float3 wpos)
{
	float4 coord = mul(_ShadowProjMatrix, float4(wpos, 1.0f));
	return coord.xyz / coord.w;
}

inline float3 GetShadowCoordinate(float3 wpos, uint cascade)
{
	float4 coord = mul(unity_World2Shadow[cascade], float4(wpos, 1.0f));
	return coord.xyz;
}

inline void SampleCoordinate(float2 uv, out float4 wpos, out float depth)
{
    float4 spos = float4(mad(uv, 2.0f, -1.0f), 1.0f, 1.0f);
    float4 vpos = mul(_ClipToViewMatrix, spos);
    depth = tex2D(_CameraDepthTexture, uv);
    vpos = float4(vpos.xyz * Linear01Depth(depth) / vpos.w, 1.0f);
    wpos = mul(_ViewToWorldMatrix, vpos);
    depth = LinearEyeDepth(depth);
}

#if defined(POINT) || defined(SPOT) || defined (DIRECTIONAL)
half2 SamplePCFShadows(float3 vec, float2 uv, float depth, float ndotl)
{
	// initialize shadow coordinate and depth
	#if defined(POINT)
		float pixelDepth = length(vec) * _LightPositionRange.w;
	#elif defined(SPOT)
		float pixelDepth = GetShadowCoordinate(vec).z;
	#elif defined(DIRECTIONAL)
		uint2 cascade = GetCascadeIndex(depth);
		float2 pixelDepth = float2(GetShadowCoordinate(vec, cascade.x).z, GetShadowCoordinate(vec, cascade.y).z);
	#endif

	// slope-based bias
	#if defined(POINT) || defined(SPOT)
		float bias = saturate(1.0f - 0.01f * _SlopeBiasScale);
		pixelDepth = pixelDepth * lerp(bias, 1.0f, ndotl);
	#endif

	// penumbra sliders
	// x: blocker search radius (in cm)
	// y: light source radius (in cm)
	// z: minimum or fixed size penumbra (in mm)
	#if defined(POINT)
		float3 radius = float3(0.01f, 0.01f, 0.001f) * _PointLightPenumbra;
	#elif defined(SPOT)
		float3 radius = float3(0.01f, 0.01f, 0.001f) * _SpotLightPenumbra;
	#elif defined(DIRECTIONAL)
		float3 radius = float3(0.01f, 0.01f, 0.001f) * _DirLightPenumbra;
	#endif

	// gram-schmidt process
	#if defined(POINT)
		float3x3 tbn = GramSchmidtMatrix(uv, normalize(vec));
	#elif defined(SPOT)
		float3x3 tbn = GramSchmidtMatrix(uv, _LightDir.xyz);
	#elif defined(DIRECTIONAL)
		float3x3 tbn = GramSchmidtMatrix(uv, _LightDir.xyz);
	#endif

	///////////////////////////////////
	// percentage-closer soft shadow //
	///////////////////////////////////

	// r: shadow, g: mean z-diff.
	half2 shadow = {0.0h, 0.0h};

	#if defined(PCSS_OFF)
		// fixed sized penumbra
		float penumbra = radius.z;
		// thicc-fucking-thickness
		shadow.g = 100.0h;
	#else
		float casterCount = 0;
		float casterDepth = 0.0f;

		// blocker search loop
		[unroll]
		for (uint i = 0; i < PCF_NUM_TAPS; i ++)
		{
			float3 disc = mul(PoissonDisc(i, PCF_NUM_TAPS), tbn);
			float3 sampleCoord = mad(disc, radius.x, vec);

			#if defined(POINT)
				float sampleDepth = texCUBE(_MainTex, sampleCoord).x;
			#elif defined(SPOT)
				float sampleDepth = tex2D(_MainTex, GetShadowCoordinate(sampleCoord).xy).x;
			#elif defined(DIRECTIONAL)
				float sampleDepth = tex2D(_CascadeShadowMap, GetShadowCoordinate(sampleCoord, cascade.x).xy).x;
			#endif

			if (sampleDepth < pixelDepth.x)
			{
				casterCount += 1.0f;
				casterDepth += sampleDepth;
			}
		}

		casterDepth = casterCount > 0.0f ? casterDepth / casterCount : pixelDepth;

		// penumbra size
		#if defined(DIRECTIONAL)
			float penumbra = max(radius.z, radius.y * (pixelDepth.x - casterDepth));
		#elif defined(POINT) || defined(SPOT)
			float penumbra = max(radius.z, radius.y * (pixelDepth.x - casterDepth) / casterDepth);
		#endif

		// thickness calculation
		shadow.g = max(0.0f, pixelDepth.x - casterDepth);
	#endif

	/////////////////////////////////
	// percentage closer filtering //
	/////////////////////////////////

	[unroll]
	for (uint j = 0; j < PCF_NUM_TAPS; j ++)
	{
		float3 disc = mul(PoissonDisc(j, PCF_NUM_TAPS), tbn);
		float3 sampleCoord = mad(disc, penumbra, vec.xyz);

		#if defined(POINT)
			shadow.r += step(pixelDepth, texCUBE(_MainTex, sampleCoord).x);
		#elif defined(SPOT)
			shadow.r += step(pixelDepth, tex2D(_MainTex, GetShadowCoordinate(sampleCoord).xy).x);
		#elif defined(DIRECTIONAL)
			shadow.r += step(pixelDepth.x, tex2D(_CascadeShadowMap, GetShadowCoordinate(sampleCoord, cascade.x).xy).x);
		#endif
	}

	shadow.x = saturate(shadow.x / PCF_NUM_TAPS);

	return shadow.x;
}
#endif
#endif

half frag_shadow (v2f_img i) : SV_TARGET
{
#ifdef SHADOWS_OFF
	return 1.0h;
#else
	float2 uv = i.uv;

	if (_SparseRendering)
	{
		uint2 coord = round((uv - 0.5f * TexelSize.xy) * TexelSize.zw);
		coord.x = coord.y % 2 == _FrameCount % 2 ? 2 * coord.x : 2 * coord.x + 1;
		uv = ((float2) coord + 0.5f) * TexelSize.xy;
		if (uv.x > 1.0f) discard;
	}

	float4 wpos;
	float depth;

	SampleCoordinate(uv, wpos, depth);

	// ndotl calculation
	half3 normal = tex2D(_CameraGBufferTexture2, uv);
	normal = normalize(mad(normal, 2.0h, -1.0h));
	float ndotl = saturate(dot(normal, normalize(_LightPos.xyz - wpos.xyz)));

	half shadow = 0.0f;

	#if defined(POINT)
		shadow = SamplePCFShadows(wpos.xyz - _LightPos.xyz, uv, depth, ndotl);
	#elif defined(SPOT) || defined(DIRECTIONAL)
		shadow = SamplePCFShadows(wpos.xyz, uv, depth, ndotl);
	#endif

	//float fadeDist = UnityDeferredComputeFadeDistance(wpos.xyz, depth);
	//float fade = fadeDist * _LightShadowData.z + _LightShadowData.w;
	//fade = saturate(fade);
	return shadow;
#endif
}

#endif