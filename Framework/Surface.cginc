#ifndef HSSSS_FRAMEWORK_SURFACE
#define HSSSS_FRAMEWORK_SURFACE

#include "Assets/HSSSS/Config.cginc"
#include "Assets/HSSSS/Framework/Brdf.cginc"
#include "Assets/HSSSS/Framework/Utility.cginc"

#include "HLSLSupport.cginc"
#include "UnityCG.cginc"
#include "UnityStandardBRDF.cginc"
#include "UnityStandardUtils.cginc"

#ifndef A_SURFACE_CUSTOM_LIGHTING_DATA
    #define A_SURFACE_CUSTOM_LIGHTING_DATA
#endif

#if defined(UNITY_PASS_DEFERRED) || defined(UNITY_PASS_FORWARDADD) || defined(UNITY_PASS_FORWARDBASE)
    #define A_NORMAL_WORLD(s, normalTangent) (normalize(mul(normalTangent, s.tangentToWorld)))
    #define A_NORMAL_TANGENT(s, normalWorld) (normalize(mul(s.tangentToWorld, normalWorld)))
#else
    #define A_NORMAL_WORLD(s, normalTangent) (s.normalWorld)
    #define A_NORMAL_TANGENT(s, normalWorld) (s.normalTangent)
#endif

/// Picks either UV0 or UV1.
#define A_UV(s, name) ((name##UV < 0.5f) ? s.uv01.xy : s.uv01.zw)

/// Applies Unity texture transforms plus UV-switching effect.
#define A_TRANSFORM_UV(s, name) (TRANSFORM_TEX(A_UV(s, name), name))

/// Applies Unity texture transforms plus UV-switching and our scrolling effects.
#define A_TRANSFORM_UV_SCROLL(s, name) (A_TRANSFORM_SCROLL(name, A_UV(s, name)))

/// Contains ALL data and state for rendering a surface.
/// Can set state to control how features are combined into the surface data.
struct ASurface {
    /////////////////////////////////////////////////////////////////////////////
    // Vertex Inputs.
    /////////////////////////////////////////////////////////////////////////////
    
    /// Screen-space texture coordinates.
    float2 screenUv;

    /// Unity's fog data.
    float fogCoord;

    /// The model's UV0 & UV1 texture coordinate data.
    /// Be aware that it can have parallax precombined with it.
    float4 uv01;
        
    /// Tangent space to World space rotation matrix.
    half3x3 tangentToWorld;

    /// Position in world space.
    float3 positionWorld;
        
    /// View direction in world space.
    /// Expects a normalized vector.
    half3 viewDirWorld;
        
    /// View direction in tangent space.
    /// Expects a normalized vector.
    half3 viewDirTangent;
    
    /// Distance from the camera to the given fragement.
    /// Expects values in the range [0,n].
    half viewDepth;
    
    /// Vertex color.
    /// Expects linear-space LDR color values.
    half4 vertexColor;


    /////////////////////////////////////////////////////////////////////////////
    // Feature layering options.
    /////////////////////////////////////////////////////////////////////////////
    
    /// Masks where the next feature layer will be applied.
    /// Expects values in the range [0,1].
    half mask;
        
    /// The base map's texture transform tiling amount.
    float2 baseTiling;
        
    /// Transformed texture coordinates for the base map.
    /// Be aware that it can have parallax precombined with it.
    float2 baseUv;
    

    /////////////////////////////////////////////////////////////////////////////
    // Material data.
    /////////////////////////////////////////////////////////////////////////////
    
    /// Controls opacity or cutout regions.
    /// Expects values in the range [0,1].
    half opacity;
        
    /// Diffuse ambient occlusion.
    /// Expects values in the range [0,1].
    half ambientOcclusion;
    
    /// Albedo and/or Metallic f0 based on settings. Used by Enlighten.
    /// Expects linear-space LDR color values.
    half3 baseColor;
    
    /// Linear control of dielectric f0 from [0.00,0.08].
    /// Expects values in the range [0,1].
    half specularity;

#ifdef _WORKFLOW_SPECULAR
    half3 specularColor;
#endif
#ifdef A_SPECULAR_TINT_ON
    /// Tints the dielectric specularity by the base color chromaticity.
    /// Expects values in the range [0,1].
    half specularTint;
#endif
#ifdef A_CLEARCOAT_ON
    /// Strength of clearcoat layer, used to apply masks.
    /// Expects values in the range [0,1].
    half clearCoatWeight;
    
    /// Roughness of clearcoat layer.
    /// Expects values in the range [0,1].
    half clearCoatRoughness;
#endif
    
    /// Interpolates material from dielectric to metal.
    /// Expects values in the range [0,1].
    half metallic;
        
    /// Linear roughness value, where zero is smooth and one is rough.
    /// Expects values in the range [0,1].
    half roughness;
    
    /// Normal in tangent space.
    /// Expects a normalized vector.
    half3 normalTangent;
    
    /// Light emission by the material. Used by Enlighten.
    /// Expects linear-space HDR color values.
    half3 emission;

    /// Monochrome linear transmission.
    /// Expects values in the range [0,1].
    half transmission;


    /////////////////////////////////////////////////////////////////////////////
    // BRDF inputs.
    /////////////////////////////////////////////////////////////////////////////
    
    /// Diffuse albedo.
    /// Expects linear-space LDR color values.
    half3 albedo;
    
    /// Fresnel reflectance at incidence zero.
    /// Expects linear-space LDR color values.
    half3 f0;
    
    /// Beckmann roughness.
    /// Expects values in the range [0,1].
    half beckmannRoughness;
    
    /// Specular occlusion.
    /// Expects values in the range [0,1].
    half specularOcclusion;

    /// Subsurface scattering mask.
    /// Expects values in the range [0,1].
    half scatteringMask;
    
    /// Normal in world space.
    /// Expects normalized vectors in the range [-1,1].
    half3 normalWorld;

    /// View reflection vector in world space.
    /// Expects a non-normalized vector.
    half3 reflectionVectorWorld;
    
    /// Clamped N.V.
    /// Expects values in the range [0,1].
    half NdotV;

    half3 ambientNormalWorld;

#ifdef _VIRTUALTEXTURING_ON
    VirtualCoord baseVirtualCoord;
#endif
    
    A_SURFACE_CUSTOM_LIGHTING_DATA
};

/// Constructor. 
/// @return Structure initialized with sane default values.
ASurface aCreateSurface() {
    ASurface s;

    UNITY_INITIALIZE_OUTPUT(ASurface, s);
    s.mask = 1.0h;
    s.opacity = 1.0h;
    s.baseColor = 1.0h;
#ifdef _SPECCOLOR_ON
    s.specularColor = 1.0h;
#endif
#ifdef A_SPECULAR_TINT_ON
    s.specularTint = 0.0h;
#endif
#ifdef A_CLEARCOAT_ON
    s.clearCoatWeight = 0.0h;
    s.clearCoatRoughness = 0.0h;
#endif
    s.metallic = 0.0h;
    s.specularity = 0.5h;
    s.roughness = 0.0h; 
    s.emission = 0.0h;
    s.ambientOcclusion = 1.0h;
    s.normalTangent = A_FLAT_NORMAL;
    s.scatteringMask = 0.0h;
    s.transmission = 0.0h;
    
    return s;
}

/// Zeroes out the material properties of the surface. 
/// @param[in,out] s Material surface data.
void aZeroOutSurface(
    inout ASurface s) 
{
    s.baseColor = 0.0h;
    s.metallic = 0.0h;
    s.ambientOcclusion = 0.0h;
    s.specularity = 0.0h;
#ifdef _SPECCOLOR_ON
    s.specularColor = 0.0h;
#endif
#ifdef A_SPECULAR_TINT_ON
    s.specularTint = 0.0h;
#endif
#ifdef A_CLEARCOAT_ON
    s.clearCoatWeight = 0.0h;
    s.clearCoatRoughness = 0.0h;
#endif
    s.roughness = 0.0h;
    s.emission = 0.0h;
    s.normalTangent = 0.0h;
    s.normalWorld = 0.0h;
}

/// Calculates view-dependent vectors.
/// @param[in,out] s Material surface data.
void aUpdateViewData(
    inout ASurface s)
{
    s.reflectionVectorWorld = reflect(-s.viewDirWorld, s.normalWorld);
    s.NdotV = aDotClamp(s.normalWorld, s.viewDirWorld);
}

/// Calculates world-space normal data from the tangent-space normal.
/// @param[in,out] s Material surface data.
void aUpdateNormalData(
    inout ASurface s)
{
    s.normalWorld = A_NORMAL_WORLD(s, s.normalTangent);
    aUpdateViewData(s);
}

/// Calculates specular inputs.
/// @param[in,out] s Material surface data.
void aUpdateSpecularData(inout ASurface s)
{
    s.beckmannRoughness = aLinearToBeckmannRoughness(s.roughness);
    s.specularOcclusion = aSpecularOcclusion(s.ambientOcclusion, s.NdotV);
}

/// Calculates and sets PBR BRDF inputs.
/// @param[in,out] s Material surface data.
void aUpdateBrdfData(inout ASurface s)
{
    #ifdef _WORKFLOW_SPECULAR
        s.albedo = saturate(s.baseColor);
        s.f0 = saturate(s.specularColor);
    #else
        half metallicInv = 1.0h - s.metallic;
        half3 dielectricF0 = aSpecularityToF0(s.specularity);
    
        // Ensures energy-conserving color when using weird detail modes.
        s.baseColor = saturate(s.baseColor);
    
        #ifdef A_SPECULAR_TINT_ON
            dielectricF0 *= aSpecularTint(s.baseColor, s.specularTint);
        #endif
    
        s.albedo = s.baseColor * metallicInv;
        s.f0 = lerp(dielectricF0, s.baseColor, s.metallic);
    
        #ifdef A_CLEARCOAT_ON
            // Specularity of 0.5 gives us a polyurethane like coating.
            half FV = aFresnel(s.NdotV);
            half clearCoatWeight = s.clearCoatWeight * lerp(0.04h, 1.0h, FV);
            s.albedo *= lerp(1.0h, 0.0h, clearCoatWeight);
            s.f0 = lerp(s.f0, 1.0h, clearCoatWeight);
            s.roughness = lerp(s.roughness, s.clearCoatRoughness, clearCoatWeight);

            /*
            half clearCoatWeight = 0.5h * s.clearCoatWeight;
            s.f0 += aSpecularityToF0(clearCoatWeight);
            s.f0 = saturate(s.f0);
            s.roughness = lerp(s.roughness, s.clearCoatRoughness, clearCoatWeight);
            */
        #endif

        #ifdef _ALPHAPREMULTIPLY_ON
            // Interpolate from a translucent dielectric to an opaque metal.
            s.opacity = s.metallic + metallicInv * s.opacity;
            // Premultiply opacity with albedo for translucent shaders.
            s.albedo *= s.opacity;
        #endif

        // Transmission can't happen through metal.
        s.transmission *= metallicInv;
    #endif
}

#endif // A_FRAMEWORK_SURFACE_CGINC
