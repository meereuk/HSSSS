#ifndef A_FEATURES_DISSOLVE_CGINC
#define A_FEATURES_DISSOLVE_CGINC

#ifndef A_SURFACE_IN_SHADOW_PASS
    #define A_SURFACE_IN_SHADOW_PASS
#endif

#ifdef _DISSOLVE_ON
    /// Dissolve glow tint color.
    /// Expects a linear HDR color with alpha.
    half4 _DissolveGlowColor; 
    
    /// Dissolve glow color with effect ramp in the alpha.
    /// Expects an RGBA map with sRGB sampling.
    A_SAMPLER2D(_DissolveTex);
    
    /// The cutoff value for the dissolve effect in the ramp map.
    /// Expects values in the range [0,1].
    half _DissolveCutoff;

    #ifndef A_DISSOLVE_GLOW_OFF
        /// The weight of the dissolve glow effect.
        /// Expects linear space value in the range [0,1].
        half _DissolveGlowWeight;
    
        /// The width of the dissolve glow effect.
        /// Expects values in the range [0,1].
        half _DissolveEdgeWidth;
    #endif
#endif

/// Applies the Dissolve feature to the given material data.
/// @param[in,out] s Material surface data.
void aDissolve(
    inout ASurface s) 
{
#ifdef _DISSOLVE_ON
    float2 dissolveUv = A_TRANSFORM_UV(s, _DissolveTex);
    half4 dissolveBase = _DissolveGlowColor * tex2D(_DissolveTex, dissolveUv);
    half dissolveCutoff = s.mask * _DissolveCutoff * 1.01h;
    half clipval = dissolveBase.a - dissolveCutoff;	
    
    clip(clipval); // NOTE: Eliminates need for blend edge.
    
	#ifndef A_DISSOLVE_GLOW_OFF
		// Dissolve glow
		s.emission += dissolveBase.rgb * (
					_DissolveGlowWeight
					* step(clipval, _DissolveEdgeWidth) // Outer edge.
					* step(0.01h, dissolveCutoff)); // Kill when cutoff is zero.
	#endif
#endif
} 

#endif
