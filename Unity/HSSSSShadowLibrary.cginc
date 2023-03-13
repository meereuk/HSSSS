#ifndef HSSSS_SHADOWLIB_CGINC
#define HSSSS_SHADOWLIB_CGINC

#if defined(DIRECTIONAL)
#define SHADOWMODE_DIR
#endif

#if defined(SPOT)
#define SHADOWMODE_SPOT
#endif

#if defined(POINT)
#define SHADOWMODE_POINT
#endif

// Poisson Disc for Sampling
// 64-tap PCF
#if defined(_PCF_TAPS_64)
	#define PCF_NUM_TAPS 64
	const static float2 poissonDisk[PCF_NUM_TAPS] =
	{
		{0.088388, 0.000000}, {-0.112890, 0.103409}, {0.017294, -0.196884}, {0.142265, 0.185602},
		{-0.261105, -0.046225}, {0.247377, -0.157297}, {-0.082801, 0.307744}, {-0.157703, -0.303838},
		{0.342284, 0.125116}, {-0.356177, 0.146887}, {0.171812, -0.366801}, {0.126702, 0.404517},
		{-0.382275, -0.221762}, {0.448614, -0.098402}, {-0.273954, 0.389245}, {-0.062974, -0.488080},
		{0.388060, 0.327448}, {-0.522479, 0.021279}, {0.381350, -0.378992}, {-0.025882, 0.551378},
		{-0.362297, -0.434803}, {0.574365, 0.077732}, {-0.486983, 0.338246},{0.133497, -0.591072},
		{0.307141, 0.537100}, {-0.601181, -0.192402}, {0.584400, -0.269330}, {-0.253665, 0.604435},
		{-0.225208, -0.628167}, {0.600639, 0.316497}, {-0.667727, 0.175223}, {0.380103, -0.589669},
		{0.119873, 0.702455}, {-0.571470, -0.443689}, {0.731777, -0.059705}, {-0.506463, 0.546061},
		{0.004684, -0.755176}, {0.513533, 0.567645}, {-0.772194, -0.072655}, {0.626468, -0.474052},
		{-0.143532, 0.782439}, {-0.427856, -0.682185}, {0.785587, 0.216602}, {-0.734080, 0.375252},
		{0.291126, -0.781382}, {0.316619, 0.781467}, {-0.769645, -0.366345}, {0.823701, -0.252398},
		{-0.441481, 0.750271}, {-0.183094, -0.860183}, {0.723230, 0.515752}, {-0.890364, 0.109269},
		{0.588372, -0.688572}, {0.031539, 0.913752}, {-0.646421, -0.658561}, {0.929916, 0.049433},
		{-0.725554, 0.596979}, {0.132943, -0.938490}, {0.540524, 0.788604}, {-0.939178, -0.218249},
		{0.846992, -0.477406}, {-0.304583, 0.931755}, {-0.408046, -0.900034}, {0.916072, 0.391151}
	};
// 32-tap PCF
#elif defined(_PCF_TAPS_32)
	#define PCF_NUM_TAPS 32
	const static float2 poissonDisk[PCF_NUM_TAPS] =
	{
		{0.125000, 0.000000}, {-0.159650, 0.146242}, {0.024457, -0.278436}, {0.201193, 0.262481},
		{-0.369258, -0.065373}, {0.349843, -0.222451}, {-0.117098, 0.435216}, {-0.223025, -0.429692},
		{0.484063, 0.176940}, {-0.503710, 0.207729}, {0.242979, -0.518735}, {0.179183, 0.572074},
		{-0.540619, -0.313618}, {0.634436, -0.139161}, {-0.387429, 0.550476}, {-0.089059, -0.690249},
		{0.548799, 0.463081}, {-0.738897, 0.030093}, {0.539310, -0.535976}, {-0.036603, 0.779766},
		{-0.512365, -0.614904}, {0.812275, 0.109929}, {-0.688698, 0.478352}, {0.188793, -0.835902},
		{0.434363, 0.759575}, {-0.850199, -0.272098}, {0.826467, -0.380890}, {-0.358737, 0.854800},
		{-0.318493, -0.888362}, {0.849432, 0.447594}, {-0.944309, 0.247803}, {0.537547, -0.833918}
	};
// 16-tap PCF
#elif defined(_PCF_TAPS_16)
	#define PCF_NUM_TAPS 16
	const static float2 poissonDisk[PCF_NUM_TAPS] =
	{
		{0.176777, 0.000000}, {-0.225780, 0.206818}, {0.034587, -0.393769}, {0.284530, 0.371204},
		{-0.522210, -0.092451}, {0.494753, -0.314594}, {-0.165602, 0.615488}, {-0.315405, -0.607676},
		{0.684569, 0.250232}, {-0.712353, 0.293773}, {0.343624, -0.733602}, {0.253403, 0.809035},
		{-0.764550, -0.443523}, {0.897228, -0.196804}, {-0.547908, 0.778490}, {-0.125948, -0.976159}
	};
// 8-tap PCF
#else
	#define PCF_NUM_TAPS 8
	const static float2 poissonDisk[PCF_NUM_TAPS] =
	{
		{0.250000, 0.000000}, {-0.319301, 0.292484}, {0.048913, -0.556873}, {0.402387, 0.524962},
		{-0.738516, -0.130745}, {0.699687, -0.444903}, {-0.234196, 0.870432}, {-0.446050, -0.859383}
	};
#endif

// x : blocker search radius
// y : light radius (tangent for directional)
// z : minimum penumbra radius (also fixed pcf penumbra radius)
#if defined(SHADOWMODE_DIR)
//uniform texture2D _CustomShadowMap;
//uniform SamplerState sampler_CustomShadowMap; 
uniform sampler2D _CustomShadowMap;
uniform float4 _CustomShadowMap_TexelSize;
uniform float3 _DirLightPenumbra;
#endif

#if defined(SHADOWMODE_SPOT)
//uniform texture2D _ShadowMapTexture;
//uniform SamplerState sampler_ShadowMapTexture;
uniform sampler2D _ShadowMapTexture;
uniform float4 _ShadowMapTexture_TexelSize;
uniform float3 _SpotLightPenumbra;
#endif

#if defined(SHADOWMODE_POINT)
//uniform textureCUBE _ShadowMapTexture;
//uniform SamplerState sampler_ShadowMapTexture;
uniform samplerCUBE _ShadowMapTexture;
uniform float4 _ShadowMapTexture_TexelSize;
uniform float3 _PointLightPenumbra;
#endif

uniform sampler2D _ShadowJitterTexture;
uniform float4 _ShadowJitterTexture_TexelSize;

// cascade weights
inline float4 GetCascadeWeights(float viewDepth)
{
	return float4(viewDepth >= _LightSplitsNear) * float4(viewDepth < _LightSplitsFar);	
}

// shadorcoord for directional and spot
inline float4 GetShadowCoordinate(float3 vec, float viewDepth)
{
	float4 wpos = float4(vec, 1.0f);

	#if defined(SHADOWMODE_DIR)
		float4 coord[4] = {
			mul(unity_World2Shadow[0], wpos),
			mul(unity_World2Shadow[1], wpos),
			mul(unity_World2Shadow[2], wpos),
			mul(unity_World2Shadow[3], wpos)
		};
		float4 weight = GetCascadeWeights(viewDepth);
		return coord[0] * weight.x + coord[1] * weight.y + coord[2] * weight.z + coord[3] * weight.w;
	#elif defined(SHADOWMODE_SPOT)
		return mul(unity_World2Shadow[0], wpos);
	#endif
	
	return 0.0f;
}

// uv offset scaling for directional and spot
inline float GetOffsetScale(float viewDepth)
{
	float4 rotation = float4(normalize(cross(_LightDir.xyz, _LightDir.zxy)), 0.0f);

	#if defined(SHADOWMODE_DIR)
		float4 coord[4] = {
			mul(unity_World2Shadow[0], rotation),
			mul(unity_World2Shadow[1], rotation),
			mul(unity_World2Shadow[2], rotation),
			mul(unity_World2Shadow[3], rotation)
		};
		float4 weight = GetCascadeWeights(viewDepth);
		float4 refCoord = coord[0] * weight.x + coord[1] * weight.y + coord[2] * weight.z + coord[3] * weight.w;
		return length(refCoord.xy);
	#elif defined(SHADOWMODE_SPOT)
		float4 refCoord = mul(unity_World2Shadow[0], rotation);
		return length(refCoord.xy);
	#endif

	return 1.0f;
}

// shadow acne filter, from jensen's inequality
inline float ShadowAcneFilter(float4 occluderDepth, float receiverDepth)
{
	float2 occlusion;
	occlusion.x = dot(occluderDepth > receiverDepth, 0.25f);
	occlusion.y = dot(occluderDepth, 0.25f) > receiverDepth;
	return 1.0f - (1.0f - occlusion.x) * (1.0f - occlusion.y);
}

inline float2 SamplePCFShadowMap(float3 vec, float2 uv, float viewDepth, half NdotL)
{
	// r: shadow, g: mean z-diff.
	float2 shadow = float2(0.0f, 0.0f);

	#if defined(SHADOWMODE_POINT)
		float3 rotationX = normalize(cross(vec, vec.zxy));
		float3 rotationY = normalize(cross(vec, rotationX));
		float receiverDepth = length(vec) * _LightPositionRange.w;
	#elif defined(SHADOWMODE_SPOT)
		float4 shadowCoord = GetShadowCoordinate(vec, viewDepth);
		float2 shadowUv = shadowCoord.xy / shadowCoord.w;
		float receiverDepth = shadowCoord.z / shadowCoord.w;
		float offsetScale = GetOffsetScale(viewDepth);
		float depthScaleFactor = abs(GetShadowCoordinate(vec + _LightDir, viewDepth).z / GetShadowCoordinate(vec + _LightDir, viewDepth).w - receiverDepth);
	#elif defined(SHADOWMODE_DIR)
		float4 shadowCoord = GetShadowCoordinate(vec, viewDepth);
		float2 shadowUv = shadowCoord.xy;
		float receiverDepth = shadowCoord.z;
		float offsetScale = GetOffsetScale(viewDepth);
		float depthScaleFactor = abs(GetShadowCoordinate(vec + _LightDir, viewDepth).z - receiverDepth);
	#endif

	// shadow jittering
	float2 jitter = mad(tex2D(_ShadowJitterTexture, uv * _ScreenParams.xy * _ShadowJitterTexture_TexelSize.xy + _Time.yy).rg, 2.0f, -1.0f);
	float2x2 rotationMatrix = float2x2(float2(jitter.x, -jitter.y), float2(jitter.y, jitter.x));

	/////////////////////////////////
	// penumbra radius calculation //
	/////////////////////////////////

	// variable penumbra (pcss)
	#if defined(_PCSS_ON)
		#if defined(SHADOWMODE_POINT)
			float searchRadius = 0.01f * _PointLightPenumbra.x;
			float lightRadius = 0.01f * _PointLightPenumbra.y;
		#elif defined(SHADOWMODE_SPOT)
			float searchRadius = 0.01f * _SpotLightPenumbra.x * offsetScale * receiverDepth / (receiverDepth - _LightShadowData.w * depthScaleFactor) / shadowCoord.w;
			float lightRadius = 0.01f * _SpotLightPenumbra.y;
		#elif defined(SHADOWMODE_DIR)
			float searchRadius = 0.01f * _DirLightPenumbra.x * offsetScale;
			float lightRadius = 0.01f * _DirLightPenumbra.y;
		#endif

		int occluderCount = 0;
		float occluderMeanDepth = 0.0f;

		// occluder search
		[unroll]
		for (int i = 0; i < PCF_NUM_TAPS; i ++)
		{
			float2 disk = mul(poissonDisk[i], rotationMatrix);

			#if defined(SHADOWMODE_POINT)
				//float3 sampleUv = mad(rotationX * poissonDisk[i].x + rotationY * poissonDisk[i].y, searchRadius, vec);
				float3 sampleUv = mad(rotationX * disk.x + rotationY * disk.y, searchRadius, vec);
				float occluderDepth = texCUBE(_ShadowMapTexture, sampleUv);
				if (occluderDepth < receiverDepth)
				{
					occluderCount += 1;
					occluderMeanDepth  += occluderDepth;
				}
			#elif defined(SHADOWMODE_SPOT)
				//float2 sampleUv = mad(poissonDisk[i], searchRadius, shadowUv);
				float2 sampleUv = mad(disk, searchRadius, shadowUv);
				float occluderDepth = tex2D(_ShadowMapTexture, sampleUv);
				if (occluderDepth < receiverDepth)
				{
					occluderCount += 1;
					occluderMeanDepth  += occluderDepth;
				}
			#elif defined(SHADOWMODE_DIR)
				//float2 sampleUv = mad(poissonDisk[i], searchRadius, shadowUv);
				float2 sampleUv = mad(disk, searchRadius, shadowUv);
				float occluderDepth = tex2D(_CustomShadowMap, sampleUv);
				if (occluderDepth < receiverDepth)
				{
					occluderCount += 1;
					occluderMeanDepth  += occluderDepth;
				}
			#endif
		}

		// penumbra radius
		#if defined(SHADOWMODE_POINT)
			occluderMeanDepth = occluderCount > 0 ? occluderMeanDepth / occluderCount : receiverDepth;
			float minPenumbra = _PointLightPenumbra.z * 0.001f;
			float maxPenumbra = lightRadius * abs(receiverDepth - occluderMeanDepth) / receiverDepth;
			float penumbraRadius = max(minPenumbra, maxPenumbra);
		#elif defined(SHADOWMODE_SPOT)
			occluderMeanDepth = occluderCount > 0 ? occluderMeanDepth / occluderCount : receiverDepth;
			float minPenumbra = _SpotLightPenumbra.z * 0.001f;
			float maxPenumbra = lightRadius * abs(receiverDepth - occluderMeanDepth) / receiverDepth;
			float penumbraRadius = max(minPenumbra, maxPenumbra) * offsetScale / shadowCoord.w;
		#elif defined(SHADOWMODE_DIR)
			occluderMeanDepth = occluderCount > 0 ? occluderMeanDepth / occluderCount : receiverDepth;
			float minPenumbra = _DirLightPenumbra.z * 0.001f;
			float maxPenumbra = lightRadius * abs(receiverDepth - occluderMeanDepth) / depthScaleFactor;
			float penumbraRadius = max(minPenumbra, maxPenumbra) * offsetScale;
		#endif

		// z-diff. for the deep scattering
		#if defined(SHADOWMODE_POINT)
			shadow.g = receiverDepth - occluderMeanDepth;
			shadow.g = shadow.g / _LightPositionRange.w;
		#elif defined(SHADOWMODE_SPOT)
			shadow.g = receiverDepth - occluderMeanDepth;
			shadow.g = shadow.g / depthScaleFactor;
		#elif  defined(SHADOWMODE_DIR)
			shadow.g = receiverDepth - occluderMeanDepth;
			shadow.g = shadow.g / depthScaleFactor;
		#endif

	// fixed penumbra (no pcss)
	#else
		#if defined(SHADOWMODE_POINT)
			float penumbraRadius = 0.001f * _PointLightPenumbra.z;
		#elif defined(SHADOWMODE_SPOT)
			float penumbraRadius = 0.001f * _SpotLightPenumbra.z * offsetScale / shadowCoord.w;
		#elif defined(SHADOWMODE_DIR)
			float penumbraRadius = 0.001f * _DirLightPenumbra.z * offsetScale;
		#endif
	#endif

	//////////////////////////////
	// pcf soft shadow sampling //
	//////////////////////////////

	// slope-based bias
	#if defined(SHADOWMODE_POINT)
		receiverDepth = receiverDepth * lerp(0.990f, 1.0f, NdotL) - lerp(0.001f, 0.0f, NdotL) * _LightPositionRange.w;
	#elif defined(SHADOWMODE_SPOT) || defined(SHADOWMODE_DIR)
		receiverDepth = receiverDepth - lerp(0.001f, 0.0f, NdotL) * depthScaleFactor;
	#endif

	[unroll]
	for (int j = 0; j < PCF_NUM_TAPS; j ++)
	{
		float2 disk = mul(poissonDisk[j], rotationMatrix);

		#if defined(SHADOWMODE_POINT)
			float3 sampleUv = mad(rotationX * disk.x + rotationY * disk.y, penumbraRadius, vec);
			shadow.r += texCUBE(_ShadowMapTexture, sampleUv) > receiverDepth ? 1.0f : 0.0f;
		#elif defined(SHADOWMODE_SPOT)
			float2 sampleUv = mad(disk, penumbraRadius, shadowUv);
			shadow.r += tex2D(_ShadowMapTexture, sampleUv) > receiverDepth ? 1.0f : 0.0f;
		#elif defined(SHADOWMODE_DIR)
			float2 sampleUv = mad(disk, penumbraRadius, shadowUv);
			shadow.r += tex2D(_CustomShadowMap, sampleUv) > receiverDepth ? 1.0f : 0.0f;
		#endif
	}

	shadow.r = lerp(shadow.r / PCF_NUM_TAPS, 1.0f, _LightShadowData.r);

	return shadow;
}

#endif