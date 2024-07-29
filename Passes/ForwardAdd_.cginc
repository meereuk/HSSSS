#ifndef A_PASSES_FORWARD_ADD_CGINC
#define A_PASSES_FORWARD_ADD_CGINC

#include "AutoLight.cginc"

struct AVertexToFragment {
    A_VERTEX_DATA(0, 1, 2, 3, 4, 5, 6)
    float4 lightVectorRange : TEXCOORD7;
    SHADOW_COORDS(8)
    UNITY_FOG_COORDS(9)
};

#include "Assets/HSSSS/Framework/Pass.cginc"

uniform sampler2D _ScreenSpaceShadowMap;

void aVertexShader(AVertex v, out AVertexToFragment o, out float4 opos : SV_POSITION)
{
    aTransferVertex(v, o, opos);
    o.lightVectorRange = aLightVectorRange(o.positionWorld);
    A_TRANSFER_SHADOW(o);
    UNITY_TRANSFER_FOG(o, opos);
}

half4 aFragmentShader(AVertexToFragment i) : SV_Target
{
    ASurface s = aForwardSurface(i);

    half shadow =
    #if defined(_PCF_ON)
        tex2D(_ScreenSpaceShadowMap, s.screenUv);
    #else
        SHADOW_ATTENUATION(i);
    #endif

    half3 illum = aForwardDirect(s, i.lightVectorRange.xyz, i.lightVectorRange.w, shadow);

    return aOutputForward(s, i, illum);
}
            
#endif