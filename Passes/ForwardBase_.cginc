#ifndef A_PASSES_FORWARD_BASE_CGINC
#define A_PASSES_FORWARD_BASE_CGINC

#include "AutoLight.cginc"

struct AVertexToFragment {
    A_VERTEX_DATA(0, 1, 2, 3, 4, 5, 6)

#ifdef A_LIGHTING_OFF
    UNITY_FOG_COORDS(7)
#else
    A_GI_DATA(7)
    SHADOW_COORDS(8)
    UNITY_FOG_COORDS(9)
#endif
};

#include "Assets/HSSSS/Framework/Pass.cginc"

uniform sampler2D _ScreenSpaceShadowMap;

void aVertexShader(AVertex v, out AVertexToFragment o, out float4 opos : SV_POSITION)
{
    aTransferVertex(v, o, opos);
    aVertexGi(v, o);
    A_TRANSFER_SHADOW(o);
    UNITY_TRANSFER_FOG(o, opos);
}

half4 aFragmentShader(AVertexToFragment i) : SV_Target
{
    ASurface s = aForwardSurface(i);
    half3 illum = s.emission;

#ifndef A_LIGHTING_OFF
    half shadow =
    #if defined(_PCF_ON)
        tex2D(_ScreenSpaceShadowMap, s.screenUv);
    #else
        SHADOW_ATTENUATION(i);
    #endif

    UnityGI gi = aFragmentGi(s, i, shadow);
    illum += aGlobalIllumination(gi, s);

    #ifdef LIGHTMAP_OFF
        illum += aForwardDirect(s, _WorldSpaceLightPos0.xyz, 1.0f, shadow);
    #endif
#endif

    return aOutputForward(s, i, illum);
}
            
#endif