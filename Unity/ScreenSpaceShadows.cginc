#ifndef HSSSS_CONTACTSHADOW_CGINC
#define HSSSS_CONTACTSHADOW_CGINC

#include "Assets/HSSSS/Framework/AreaLight.cginc"

uniform sampler2D _ScreenSpaceShadowMap;

inline void SampleScreenSpaceShadow(float2 uv, inout half2 shadow)
{
	half sscs = tex2D(_ScreenSpaceShadowMap, uv);
	shadow.r = min(shadow.r , lerp(sscs, 1.0h, _LightShadowData.r));

}

#endif