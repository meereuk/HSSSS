#ifndef A_FRAMEWORK_BRDF_CGINC
#define A_FRAMEWORK_BRDF_CGINC

#include "Assets/HSSSS/Framework/Utility.cginc"
#include "UnityStandardUtils.cginc"

#define A_MAX_DIELECTRIC_F0 (0.08h)
#define A_MIN_AREA_ROUGHNESS (0.05h)

half3 aSpecularityToF0(half specularity)
{
    return (specularity * A_MAX_DIELECTRIC_F0).rrr;
}

half3 aSpecularTint(half3 color, half specularTint)
{
    return aLerpWhiteTo(aChromaticity(color), specularTint);
}

half aLinearToBeckmannRoughness(half roughness)
{
    roughness = lerp(A_MIN_AREA_ROUGHNESS, 1.0h, roughness);
    return roughness * roughness;
}

half aSpecularOcclusion(half ao, half NdotV)
{
    half d = NdotV + ao;
    return saturate((d * d) - 1.0h + ao);
}

half aFresnel(half w)
{
    return exp2((-5.55473h * w - 6.98316h) * w);
}

half3 aDiffuseBrdf(half3 albedo, half roughness, half LdotH, half NdotL, half NdotV)
{
    half FL = aFresnel(NdotL);
    half FV = aFresnel(NdotV);
    half Fd90 = 0.5h + (2.0h * LdotH * LdotH * roughness);
    half Fd = aLerpOneTo(Fd90, FL) * aLerpOneTo(Fd90, FV);

    return albedo * Fd;
}

half3 aSpecularBrdf(half3 f0, half a, half LdotH, half NdotH, half NdotL, half NdotV)
{
    // Schlick's Fresnel approximation.
    half3 f = lerp(f0, half3(1.0h, 1.0h, 1.0h), aFresnel(LdotH));

    // GGX (Trowbridge-Reitz) NDF
    half a2 = a * a;
    half denom = aLerpOneTo(a2, NdotH * NdotH);
    half d = a2 / (denom * denom);

    // John Hable's visibility function.
    half k = a * 0.5h;
    half v = lerp(k * k, 1.0h, LdotH * LdotH);

    // Cook-Torrance microfacet model.
    return f * (d / (4.0h * v));
}

half3 aEnvironmentBrdf(half3 f0, half roughness, half NdotV)
{
    // Brian Karis' modification of Dimitar Lazarov's Environment BRDF.
    // cf https://www.unrealengine.com/blog/physically-based-shading-on-mobile
    const half4 c0 = half4(-1.0h, -0.0275h, -0.572h, 0.022h);
    const half4 c1 = half4(1.0h, 0.0425h, 1.04h, -0.04h);
    half4 r = roughness * c0 + c1;
    half a004 = min(r.x * r.x, exp2(-9.28h * NdotV)) * r.x + r.y;
    half2 AB = half2(-1.04h, 1.04h) * a004 + r.zw;
    return f0 * AB.x + AB.yyy;
}

#endif