#ifndef HSSSS_FEATURES_OVERLAY
#define HSSSS_FEATURES_OVERLAY

#include "Assets/HSSSS/Framework/Surface.cginc"

inline void aFinalGbuffer(ASurface s, inout half4 gbuffer0, inout half4 gbuffer1, inout half4 gbuffer2, inout half4 gbuffer3)
{
    #if defined(A_DECAL_ALPHA_FIRSTPASS)
        gbuffer0.a = s.opacity;
        gbuffer1.a = s.opacity;
        gbuffer2.a = s.opacity;
        gbuffer3.a = s.opacity;
    #else
        gbuffer0.a *= s.opacity;
        gbuffer1.a *= s.opacity;
        gbuffer2.a *= s.opacity;
        gbuffer3.a *= s.opacity;
    #endif
}

#endif