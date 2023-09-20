#ifndef HSSSS_DEFINITIONS_UNLIT
#define HSSSS_DEFINITIONS_UNLIT

#include "Assets/HSSSS/Lighting/Unlit.cginc"
#include "Assets/HSSSS/Framework/Definition.cginc"

void aSurface(inout ASurface s)
{
    s.baseColor = 0.0h;
    s.opacity = tex2D(_MainTex, s.baseUv).a;
}

#endif