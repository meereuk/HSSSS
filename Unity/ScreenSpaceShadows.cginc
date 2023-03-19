#ifndef HSSSS_CONTACTSHADOW_CGINC
#define HSSSS_CONTACTSHADOW_CGINC

#include "Assets/HSSSS/Framework/AreaLight.cginc"

sampler2D _ScreenSpaceShadowMap;

inline void SampleScreenSpaceShadow(float3 pos, float2 uv, inout half2 shadow)
{
	half sscs = tex2D(_ScreenSpaceShadowMap, uv);
	shadow.r = min(shadow.r , lerp(sscs, 1.0h, _LightShadowData.r));
}

#endif