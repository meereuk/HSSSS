#ifndef A_PASSES_DEFERRED_CGINC
#define A_PASSES_DEFERRED_CGINC

struct AVertexToFragment {
    A_VERTEX_DATA(0, 1, 2, 3, 4, 5, 6)
    A_GI_DATA(7)
};

#include "Assets/HSSSS/Framework/Pass.cginc"

void aVertexShader(
    AVertex v,
    out AVertexToFragment o,
    out float4 opos : SV_POSITION)
{
    aTransferVertex(v, o, opos);
    aVertexGi(v, o);
}

void aFragmentShader(
    AVertexToFragment i,
    out half4 outDiffuseOcclusion : SV_Target0,
    out half4 outSpecSmoothness : SV_Target1,
    out half4 outNormal : SV_Target2,
    out half4 outEmission : SV_Target3)
{
    aOutputDeferred(i, outDiffuseOcclusion, outSpecSmoothness, outNormal, outEmission);
}					
            
#endif