#ifndef A_PASSES_SHADOW_CGINC
#define A_PASSES_SHADOW_CGINC

// Do dithering for alpha blended shadows on SM3+/desktop;
// on lesser systems do simple alpha-tested shadows
#if defined(A_ALPHA_BLENDING_ON) && !(defined (SHADER_API_MOBILE) || defined(SHADER_API_D3D11_9X) || defined (SHADER_API_PSP2) || defined (SHADER_API_PSM))
    #define UNITY_STANDARD_USE_DITHER_MASK 
#endif

// Need to output UVs in shadow caster, since we need to sample texture and do clip/dithering based on it
#if !(defined(A_SURFACE_IN_SHADOW_PASS) || defined(_ALPHATEST_ON) || defined(A_ALPHA_BLENDING_ON))
    #define A_SURFACE_SHADER_OFF
#endif

// Has a non-empty shadow caster output struct (it's an error to have empty structs on some platforms...)
#if defined(V2F_SHADOW_CASTER_NOPOS_IS_EMPTY) && defined(A_SURFACE_SHADER_OFF)
    #define A_VERTEX_TO_FRAGMENT_OFF
#endif

#ifndef A_VERTEX_TO_FRAGMENT_OFF
    struct AVertexToFragment {
        V2F_SHADOW_CASTER_NOPOS
    #ifndef A_SURFACE_SHADER_OFF
        A_VERTEX_DATA(1, 2, 3, 4, 5, 6, 7)
    #endif
    };
#endif

#include "Assets/HSSSS/Framework/Pass.cginc"

#ifdef UNITY_STANDARD_USE_DITHER_MASK
    sampler3D _DitherMaskLOD;
#endif

// We have to do these dances of outputting SV_POSITION separately from the vertex shader,
// and inputting VPOS in the pixel shader, since they both map to "POSITION" semantic on
// some platforms, and then things don't go well.

void aVertexShader(
    AVertex v,
#ifndef A_VERTEX_TO_FRAGMENT_OFF
    out AVertexToFragment o,
#endif
    out float4 opos : SV_POSITION)
{
#ifndef A_SURFACE_SHADER_OFF
    aTransferVertex(v, o, opos);
#endif
    TRANSFER_SHADOW_CASTER_NOPOS(o, opos)
}

half4 aFragmentShader(
#ifndef A_VERTEX_TO_FRAGMENT_OFF
    AVertexToFragment i
#endif
#ifdef UNITY_STANDARD_USE_DITHER_MASK
    , UNITY_VPOS_TYPE vpos : VPOS
#endif
    ) : SV_Target
{
#ifndef A_SURFACE_SHADER_OFF
    ASurface s = aForwardSurface(i);
    
    #ifdef UNITY_STANDARD_USE_DITHER_MASK
        // Use dither mask for alpha blended shadows, based on pixel position xy
        // and alpha level. Our dither texture is 4x4x16.
        half alphaRef = tex3D(_DitherMaskLOD, float3(vpos.xy * 0.25f, s.opacity * 0.9375f)).a;
        clip(alphaRef - 0.01h);
    #endif
#endif

    SHADOW_CASTER_FRAGMENT(i)
}		
            
#endif