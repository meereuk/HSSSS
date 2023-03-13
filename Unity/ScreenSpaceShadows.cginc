#ifndef HSSSS_CONTACTSHADOW_CGINC
#define HSSSS_CONTACTSHADOW_CGINC

#ifndef HSSSS_SHADOWLIB_CGINC
	uniform sampler2D _ShadowJitterTexture;
	uniform float4 _ShadowJitterTexture_TexelSize;
#endif

#if defined(_RT_SHADOW_LQ)
	#define _SSShadowTraceIter 8
#elif defined(_RT_SHADOW_MQ)
	#define _SSShadowTraceIter 16
#elif defined(_RT_SHADOW_HQ)
	#define _SSShadowTraceIter 32
#endif

uniform float _SSShadowRayLength;
uniform float _SSShadowRayRadius;
uniform float _SSShadowMeanDepth;
uniform float _SSShadowDepthBias;

uniform sampler2D _BackFaceDepthBuffer;

inline half RayTracedShadow(float3 pos, float3 vec)
{
	float3 R0 = mul(UNITY_MATRIX_V, float4(pos, 1.0f)).xyz;
	float3 RV = mul(UNITY_MATRIX_V, float4(vec, 0.0f)).xyz;

	float RL = mad(_SSShadowRayLength, RV.z, R0.z) > -_ProjectionParams.y ? (-_ProjectionParams.y - R0.z) / RV.z : _SSShadowRayLength;
	RV = RV * RL / _SSShadowTraceIter;

	bool intersect = false;

	[unroll]
	for (uint iter = 1; iter <= _SSShadowTraceIter && intersect == false; iter ++)
	{
		float3 R1 = mad(RV, iter, R0);
		float4 uv = ComputeScreenPos(mul(UNITY_MATRIX_P, float4(R1, 1.0f)));

		float rayDepth = -R1.z;

		float faceDepth = tex2Dproj(_CameraDepthTexture, uv);
		float backDepth = tex2Dproj(_BackFaceDepthBuffer, uv);

		faceDepth = LinearEyeDepth(faceDepth);
		
		backDepth = max(backDepth, faceDepth + _SSShadowMeanDepth);

		intersect = rayDepth > faceDepth && rayDepth < backDepth;
	}

	return intersect ? 0.0h : 1.0h;

	/*
	#if defined(_PCF_TAPS_8) || defined(_PCF_TAPS_16) || defined(_PCF_TAPS_32) || defined(_PCF_TAPS_64)
		float2 jitter = mad(tex2D(_ShadowJitterTexture, suv * _ScreenParams.xy * _ShadowJitterTexture_TexelSize.xy).rg, 2.0f, -1.0f);
		float2x2 rotationMatrix = float2x2(float2(jitter.x, -jitter.y), float2(jitter.y, jitter.x));

		float3 rotationX = normalize(cross(vec, vec.zxy));
		float3 rotationY = normalize(cross(vec, rotationX));

		half shadow = 0.0h;

		for (uint j = 0; j < PCF_NUM_TAPS; j ++)
		{
			float2 disk = mul(poissonDisk[j], rotationMatrix);

			float3 offset = normalize(mad(rotationX * disk.x + rotationY * disk.y, _SSShadowRayRadius, vec));
			float3 R1 = mul(UNITY_MATRIX_V, float4(pos + iter * RL * offset / _SSShadowTraceIter, 1.0f));
			float4 uv = ComputeScreenPos(mul(UNITY_MATRIX_P, R1));

			float rayDepth = -R1.z;

			float faceDepth = tex2Dproj(_CameraDepthTexture, uv);
			float backDepth = tex2Dproj(_BackFaceDepthBuffer, uv);

			faceDepth = LinearEyeDepth(faceDepth);

			shadow += rayDepth > faceDepth && rayDepth < backDepth ? 0.0h : 1.0h;
		}

		return shadow / PCF_NUM_TAPS;
	#else
		return intersect ? 0.0h : 1.0h;
	#endif
	*/
}

inline void SampleScreenSpaceShadow(float3 positionWorld, float2 screenUv, float3 lightVector, inout half2 shadow)
{
	#if defined(SHADOWS_OFF)
		return;
	#else
		float3 lightAxis = normalize(lightVector);

		/*
		half rtShadow = RayTracedShadow(positionWorld, lightAxis, screenUv);
		shadow.r = min(shadow.r, lerp(rtShadow, 1.0h, _LightShadowData.r));
		*/

		float3 rotationX = normalize(cross(lightAxis, lightAxis.zxy));
		float3 rotationY = normalize(cross(lightAxis, rotationX));

		float2 jitter = mad(tex2D(_ShadowJitterTexture, screenUv * _ScreenParams.xy * _ShadowJitterTexture_TexelSize.xy).rg, 2.0f, -1.0f);

		float3 offset = rotationX * jitter.x + rotationY * jitter.y;
		
		/*
		half rtShadow = RayTracedShadow(positionWorld, normalize(mad(_SSShadowRayRadius, offset, lightAxis)));
		shadow.r = min(shadow.r, lerp(rtShadow, 1.0h, _LightShadowData.r));
		*/

		half rtShadow = 0.0h;

		rtShadow += RayTracedShadow(positionWorld, normalize(mad(_SSShadowRayRadius, offset, lightAxis)));
		rtShadow += RayTracedShadow(positionWorld, normalize(mad(_SSShadowRayRadius,-offset, lightAxis)));

		offset = rotationX * jitter.y - rotationY * jitter.x;
		rtShadow += RayTracedShadow(positionWorld, normalize(mad(_SSShadowRayRadius, offset, lightAxis)));
		rtShadow += RayTracedShadow(positionWorld, normalize(mad(_SSShadowRayRadius,-offset, lightAxis)));

		shadow.r = min(shadow.r, lerp(rtShadow / 4.0h, 1.0h, _LightShadowData.r));
	#endif
}

#endif