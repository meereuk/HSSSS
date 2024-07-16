#ifndef HSSSS_SOFTSHADOWS_CGINC
#define HSSSS_SOFTSHADOWS_CGINC

#include "UnityCG.cginc"
#include "UnityDeferredLibrary.cginc"

#ifndef PCF_NUM_TAPS
	#define PCF_NUM_TAPS 16
#endif

uniform sampler3D _BlueNoise;

#ifndef SHADOWS_OFF
uniform uint _FrameCount;
uniform bool _DirectOcclusion;

uniform float _SlopeBiasScale;
uniform float3 _DirLightPenumbra;
uniform float3 _SpotLightPenumbra;
uniform float3 _PointLightPenumbra;

uniform float4x4 _WorldToViewMatrix;
uniform float4x4 _ViewToWorldMatrix;
uniform float4x4 _ViewToClipMatrix;
uniform float4x4 _ClipToViewMatrix;

#if defined(POINT)
    uniform samplerCUBE_float _MainTex;
#elif defined(SPOT)
    uniform sampler2D_float _MainTex;
	uniform float4 _ShadowDepthParams;
	uniform float4x4 _ShadowProjMatrix;
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

#if defined(POINT)
inline float4 GetShadowCoordinate(float3 wpos)
{
	float4 vec = {
		normalize(wpos - _LightPos.xyz),
		distance(wpos, _LightPos.xyz)
	};

	return vec;
}
#elif defined(SPOT)
inline float4 GetShadowCoordinate(float3 wpos)
{
	return mul(_ShadowProjMatrix, float4(wpos, 1.0f));
}
#elif defined(DIRECTIONAL)
inline float4 GetShadowCoordinate(float3 wpos, uint cascade)
{
	return mul(unity_World2Shadow[cascade], float4(wpos, 1.0f));
}
#endif

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
half2 SamplePCFShadows(float3 wpos, float2 uv, float depth, float3 nrm, float ndotl)
{
	// initialize shadow coordinate and depth
	#if defined(POINT)
		float pixelDepth = distance(wpos, _LightPos.xyz);
	#elif defined(SPOT)
		float pixelDepth = GetShadowCoordinate(wpos).z / GetShadowCoordinate(wpos).w;
		pixelDepth = 1.0f / (_ShadowDepthParams.z * pixelDepth + _ShadowDepthParams.w);
	#elif defined(DIRECTIONAL)
		uint2 cascade = GetCascadeIndex(depth);
		float2 pixelDepth = {
			GetShadowCoordinate(wpos, cascade.x).z,
			GetShadowCoordinate(wpos, cascade.y).z
		};
		float2 depthScale = {
			GetShadowCoordinate(wpos + _LightDir, cascade.x).z,
			GetShadowCoordinate(wpos + _LightDir, cascade.y).z
		};
		depthScale = abs(depthScale - pixelDepth);
		pixelDepth = pixelDepth / depthScale;
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
		float3x3 tbn = GramSchmidtMatrix(uv, wpos - _LightPos.xyz);
	#elif defined (SPOT) || defined(DIRECTIONAL)
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
		shadow.y = 100.0h;
	#else
		float penumbra = 0.0f;
		float casterCount = 0.0f;
		float casterDepth = 0.0f;

		// blocker search loop
		[unroll]
		for (uint i = 0; i < PCF_NUM_TAPS; i ++)
		{
			float3 disc = mul(PoissonDisc(i, PCF_NUM_TAPS), tbn);
			float3 sampleCoord = mad(disc, radius.x, wpos);
			float sampleDepth = 0.0f;

			#if defined(POINT)
				float4 shadowCoord = GetShadowCoordinate(sampleCoord);
				sampleDepth = texCUBE(_MainTex, shadowCoord.xyz);
				sampleDepth = sampleDepth / _LightPositionRange.w;
			#elif defined(SPOT)
				float4 shadowCoord = GetShadowCoordinate(sampleCoord);
				sampleDepth = tex2Dproj(_MainTex, shadowCoord);
				sampleDepth = 1.0f / (_ShadowDepthParams.z * sampleDepth + _ShadowDepthParams.w);
			#elif defined(DIRECTIONAL)
				float4 shadowCoord = GetShadowCoordinate(sampleCoord, cascade.x);
				sampleDepth = tex2D(_CascadeShadowMap, shadowCoord.xy);
				sampleDepth = sampleDepth / depthScale.x;
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
			penumbra = max(radius.z, radius.y * (pixelDepth.x - casterDepth));
		#elif defined(POINT) || defined(SPOT)
			penumbra = max(radius.z, radius.y * (pixelDepth.x - casterDepth) / casterDepth);
		#endif

		// thickness calculation
		shadow.y = max(0.0f, pixelDepth.x - casterDepth);
	#endif

	/////////////////////////////////
	// percentage closer filtering //
	/////////////////////////////////

	#if defined(POINT) || defined(SPOT)
		pixelDepth -= lerp(0.01f, 0.00f, ndotl) * _SlopeBiasScale;
	#endif

	[unroll]
	for (uint j = 0; j < PCF_NUM_TAPS; j ++)
	{
		float3 disc = mul(PoissonDisc(j, PCF_NUM_TAPS), tbn);
		float3 sampleCoord = mad(disc, penumbra, wpos);
		float shadowDepth = 0.0f;

		#if defined(POINT)
			float4 shadowCoord = GetShadowCoordinate(sampleCoord);
			shadowDepth = texCUBE(_MainTex, shadowCoord.xyz);
			shadowDepth = shadowDepth / _LightPositionRange.w;
		#elif defined(SPOT)
			float4 shadowCoord = GetShadowCoordinate(sampleCoord);
			shadowDepth = tex2Dproj(_MainTex, shadowCoord);
			shadowDepth = 1.0f / (_ShadowDepthParams.z * shadowDepth + _ShadowDepthParams.w);
		#elif defined(DIRECTIONAL)
			float4 shadowCoord = GetShadowCoordinate(sampleCoord, cascade.x);
			shadowDepth = tex2D(_CascadeShadowMap, shadowCoord.xy);
			shadowDepth = shadowDepth / depthScale.x;
		#endif

		shadow.x += step(pixelDepth, shadowDepth);
	}

	shadow.x = saturate(shadow.x / PCF_NUM_TAPS);

	return shadow;
}
#endif
#endif

half2 frag_shadow (v2f_img i) : SV_TARGET
{
#ifdef SHADOWS_OFF
	return 1.0h;
#else
	float2 uv = i.uv;

	float4 wpos;
	float depth;

	SampleCoordinate(uv, wpos, depth);

	// ndotl calculation
	half3 normal = tex2D(_CameraGBufferTexture2, uv);
	normal = normalize(mad(normal, 2.0h, -1.0h));
	float ndotl = saturate(dot(normal, normalize(_LightPos.xyz - wpos.xyz)));

	half2 shadow = 0.0f;

	#if defined(POINT)
		shadow = SamplePCFShadows(wpos.xyz, uv, depth, normal, ndotl);
	#elif defined(SPOT) || defined(DIRECTIONAL)
		shadow = SamplePCFShadows(wpos.xyz, uv, depth, normal, ndotl);
	#endif

	return shadow;
#endif
}

//
// contact shadows
//

uniform half _SSCSRayLength;
uniform half _SSCSDepthBias;
uniform half _SSCSMeanDepth;

#ifndef _SSCSNumStride
	#define _SSCSNumStride 4
#endif

#ifndef SHADOWS_OFF
half HorizonTrace(float2 uv0, float2 uv1, float4 vp0, float threshold, float radius)
{
	float slope = (uv1.y - uv0.y) / (uv1.x - uv0.x);
	float minStr = min(length(TexelSize.xx * float2(1.0f, slope)),
            length(TexelSize.yy * float2(1.0f / slope, 1.0f)));

	float str = max(minStr, pow(1.0f / _SSCSNumStride, 2));

	half4 shadow = 1.0h;
	half4 horizon = {
		mad(radius, 1.0000f, threshold),
		mad(radius, 0.3333f, threshold),
		mad(radius,-0.3333f, threshold),
		mad(radius,-1.0000f, threshold)
	};

	[unroll]
	for (uint iter = 0; iter < _SSCSNumStride && str <= 1.0f; iter ++)
	{
		str = max(str + minStr, pow((iter + 1.0f) / _SSCSNumStride, 2));

		float2 uv = lerp(uv0, uv1, str);
		float4 sp = float4(mad(uv, 2.0f, -1.0f), 1.0f, 1.0f);
		float4 vp = mul(_ClipToViewMatrix, sp);
		float zf = tex2D(_CameraDepthTexture, uv);
		vp = float4(vp.xyz * Linear01Depth(zf) / vp.w, 1.0f);
		zf = -vp.z;

		float zb = zf + _SSCSMeanDepth;

		float hf = (-vp0.z - _SSCSDepthBias - zf) / distance(vp.xy, vp0.xy);
		float hb = (-vp0.z - _SSCSDepthBias - zb) / distance(vp.xy, vp0.xy);

		shadow.x = hf > horizon.x ? 0.0f : shadow.x;
		shadow.y = hf > horizon.y ? 0.0f : shadow.y;
		shadow.z = hf > horizon.z ? 0.0f : shadow.z;
		shadow.w = hf > horizon.w ? 0.0f : shadow.w;
	}

	return dot(shadow, 0.25h);
}
#endif

half SampleSingleCS(float4 vpos, float4 vdir, float2 uv0, float3 noise, float raylen, float radius, float scale)
{
#ifdef SHADOWS_OFF
	return 1.0h;
#else
	vdir.xy = vdir.xy + float2(-vdir.y, vdir.x) * radius * scale * noise.y;
	vdir.xyz = normalize(vdir.xyz);

	float4 lpos = raylen * vdir + vpos;
	float4 spos = mul(_ViewToClipMatrix, float4(lpos.xyz, 1.0f));

	float2 uv1 = spos.xy / spos.w * 0.5f + 0.5f;
	float z0 = -vpos.z - _SSCSDepthBias;
	float z1 = -lpos.z;

	float threshold = (z0 - z1) / distance(lpos.xy, vpos.xy);

	return HorizonTrace(uv0, uv1, vpos, threshold, radius * noise.z);
#endif
}

half SampleContactShadows(float3 wpos, float3 wdir, float2 uv0)
{
#ifdef SHADOWS_OFF
	return 1.0h;
#else
	float3 noise = SampleNoise(uv0);
	float raylen = _SSCSRayLength * mad(noise.x, 0.4f, 0.8f);
	float4 vpos = mul(_WorldToViewMatrix, float4(wpos, 1.0f));
	float4 vdir = mul(_WorldToViewMatrix, float4(wdir, 0.0f));

	half shadow = 0.0h;

	float radius = 1.0f;

	#if defined(SPOT)
		radius = _SpotLightPenumbra.y * 0.01f / distance(_LightPos.xyz, wpos);
	#elif defined(POINT)
		radius = _PointLightPenumbra.y * 0.01f / distance(_LightPos.xyz, wpos);
	#elif defined(DIRECTIONAL)
		radius = _DirLightPenumbra.y * 0.01f;
	#endif

	shadow += SampleSingleCS(vpos, vdir, uv0, noise, raylen, radius,  1.0000f);
	shadow += SampleSingleCS(vpos, vdir, uv0, noise, raylen, radius,  0.3333f);
	shadow += SampleSingleCS(vpos, vdir, uv0, noise, raylen, radius, -0.3333f);
	shadow += SampleSingleCS(vpos, vdir, uv0, noise, raylen, radius, -1.0000f);

	shadow *= 0.25h;

	return shadow;
#endif
}

half frag_cshadow (v2f_img i) : SV_TARGET
{
#ifdef SHADOWS_OFF
	return 1.0h;
#else
	float2 uv = i.uv;

	float4 wpos;
	float depth;

	SampleCoordinate(uv, wpos, depth);

	half shadow = 1.0h;

	#if defined(POINT) || defined(SPOT)
		shadow = SampleContactShadows(wpos.xyz, normalize(_LightPos.xyz - wpos.xyz), uv);
	#elif defined(DIRECTIONAL)
		shadow = SampleContactShadows(wpos.xyz, -_LightDir.xyz, uv);
	#endif

	return shadow;
#endif
}

#endif