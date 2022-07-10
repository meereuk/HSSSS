#ifndef HSSSS_DEFERREDLIB_CGINC
#define HSSSS_DEFERREDLIB_CGINC

// Deferred lighting / shading helpers

// --------------------------------------------------------
// Vertex shader

struct unity_v2f_deferred {
	float4 pos : SV_POSITION;
	float4 uv : TEXCOORD0;
	float3 ray : TEXCOORD1;
};

float _LightAsQuad;

unity_v2f_deferred vert_deferred (float4 vertex : POSITION, float3 normal : NORMAL)
{
	unity_v2f_deferred o;
	o.pos = mul(UNITY_MATRIX_MVP, vertex);
	o.uv = ComputeScreenPos (o.pos);
	o.ray = mul (UNITY_MATRIX_MV, vertex).xyz * float3(-1,-1,1);
	
	// normal contains a ray pointing from the camera to one of near plane's
	// corners in camera space when we are drawing a full screen quad.
	// Otherwise, when rendering 3D shapes, use the ray calculated here.
	o.ray = lerp(o.ray, normal, _LightAsQuad);
	
	return o;
}

// --------------------------------------------------------
// Shared uniforms

sampler2D_float _CameraDepthTexture;

float4 _LightDir;
float4 _LightPos;
float4 _LightColor;
float4 unity_LightmapFade;
CBUFFER_START(UnityPerCamera2)
float4x4 _CameraToWorld;
CBUFFER_END
float4x4 _LightMatrix0;
sampler2D _LightTextureB0;

#if defined (POINT_COOKIE)
samplerCUBE _LightTexture0;
#else
sampler2D _LightTexture0;
#endif

#if defined (SHADOWS_SCREEN)
sampler2D _ShadowMapTexture;
#endif

// --------------------------------------------------------
// Shadow/fade helpers

#include "Assets/HSSSS/Unity/HSSSSShadowLibrary.cginc"

float UnityDeferredComputeFadeDistance(float3 wpos, float z)
{
	float sphereDist = distance(wpos, unity_ShadowFadeCenterAndType.xyz);
	return lerp(z, sphereDist, unity_ShadowFadeCenterAndType.w);
}

half2 UnityDeferredComputeShadow(float3 vec, float fadeDist, float2 uv)
{
	// Fade Distance;
	#if defined(SHADOWS_DEPTH) || defined(SHADOWS_SCREEN) || defined(SHADOWS_CUBE)
		float fade = fadeDist * _LightShadowData.z + _LightShadowData.w;
		fade = saturate(fade);
	#endif

	// Directional
	#if defined(DIRECTIONAL) || defined(DIRECTIONAL_COOKIE)
	#if defined(SHADOWS_SCREEN)
		float shadow = tex2D(_ShadowMapTexture, uv);
		return saturate(shadow + fade);
	#endif
	#endif

	// Spot
	#if defined(SPOT)
	#if defined(SHADOWS_DEPTH)
		float2 shadow = SamplePCFShadowMap(vec, 0.0f);
		shadow.x = saturate(shadow.x + fade);
		return shadow;
	#endif
	#endif

	// Point
	#if defined (POINT) || defined (POINT_COOKIE)
	#if defined(SHADOWS_CUBE)
		float2 shadow = SamplePCFShadowMap(vec, 0.0f);
		shadow.x = saturate(shadow.x + fade);
		return shadow;
	#endif
	#endif

	return 1.0h;
}

half2 CustomDirectionalShadow(float3 vec, float viewDepth, float fadeDist)
{
	// Fade Distance;
	#if defined(SHADOWS_DEPTH) || defined(SHADOWS_SCREEN) || defined(SHADOWS_CUBE)
		float fade = fadeDist * _LightShadowData.z + _LightShadowData.w;
		fade = saturate(fade);
	#endif

	#if defined(DIRECTIONAL) || defined(DIRECTIONAL_COOKIE)
	#if defined(SHADOWS_SCREEN)
		half2 shadow = SamplePCFShadowMap(vec, viewDepth);
		shadow.x = saturate(shadow.x + fade);
		return shadow;
	#endif
	#endif

	return 1.0h;
}

#endif