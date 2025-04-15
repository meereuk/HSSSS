#ifndef A_FRAMEWORK_BRDF_CGINC
#define A_FRAMEWORK_BRDF_CGINC

#include "Assets/HSSSS/Framework/Utility.cginc"
#include "UnityStandardUtils.cginc"

#define A_MAX_DIELECTRIC_F0 (0.08h)
#define A_MIN_AREA_ROUGHNESS (0.05h)

#define clampInfinite(x) min(x, 8192.0h)

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

// disney diffuse brdf
inline half3 aDiffuseBrdf(half roughness, half LdotH, half NdotL, half NdotV)
{
    half FL = aFresnel(NdotL);
    half FV = aFresnel(NdotV);
    half Fd90 = 0.5f + (2.0f * LdotH * LdotH * roughness);
    half Fd = aLerpOneTo(Fd90, FL) * aLerpOneTo(Fd90, FV);

    return Fd;
}

inline half3 aSubSurfaceBrdf(half roughness, half LdotH, half NdotL, half NdotV)
{
    half FL = aFresnel(NdotL);
    half FV = aFresnel(NdotV);
    half Fss90 = LdotH * LdotH * roughness;
    half Fss = aLerpOneTo(Fss90, FL) * aLerpOneTo(Fss90, FV);
    half ss =  1.25f * (Fss * (1.0f / (NdotL + NdotV) - 0.5f) + 0.5f);
    return clampInfinite(ss);
}

// schlick fresnel
inline half3 FSchlick(half3 f0, half LdotH)
{
    return lerp(f0, half3(1.0h, 1.0h, 1.0h), aFresnel(LdotH));
}

// ggx normal distribution
inline half DGGX(half a, half NdotH)
{
    half a2 = a * a;
    half denom = aLerpOneTo(a2, NdotH * NdotH);
    return clampInfinite(a2 / (denom * denom));
}

inline half DGGX(half a, half NdotH, half threshold)
{
    half a2 = a * a;
    half denom = aLerpOneTo(a2, NdotH * NdotH);
    return clamp(a2 / (denom * denom), 0.0f, threshold);
}

inline half DGGXAniso(half at, half ab, half TdotH, half BdotH, half NdotH)
{
    half a2 = at * ab;
    half3 v = half3(ab * TdotH, at * BdotH, a2 * NdotH);
    half v2 = dot(v, v);
    half w2 = a2 / v2;
    return clampInfinite(a2 * w2 * w2);
}

// 'charlie' sheen distribution
inline half DCharlie(half a, half NdotH)
{
    half invA = 1.0h / a;
    half cos2h = NdotH * NdotH;
    half sin2h = max(1.0h - cos2h, 0.0078125);
    return clampInfinite(0.5h * (2.0h + invA) * pow(sin2h, invA * 0.5h));
}

// smith visibility
inline half VSmith(half a, half NdotV, half NdotL)
{
    half a2 = a * a;
    half lambdaV = NdotL * sqrt((NdotV - a2 * NdotV) * NdotV + a2);
    half lambdaL = NdotV * sqrt((NdotL - a2 * NdotL) * NdotL + a2);
    return clampInfinite(0.5h / (lambdaV + lambdaL));
}

inline half VSmith(half a, half NdotV, half NdotL, half threshold)
{
    half a2 = a * a;
    half lambdaV = NdotL * sqrt((NdotV - a2 * NdotV) * NdotV + a2);
    half lambdaL = NdotV * sqrt((NdotL - a2 * NdotL) * NdotL + a2);
    return clamp(0.5h / (lambdaV + lambdaL), 0.0f, threshold);
}


inline half VSmithAniso(half at, half ab, half TdotV, half BdotV, half TdotL, half BdotL, half NdotV, half NdotL)
{
    half lambdaV = NdotL * length(half3(at * TdotV, ab * BdotV, NdotV));
    half lambdaL = NdotV * length(half3(at * TdotL, ab * BdotL, NdotL));
    return clampInfinite(0.5h / (lambdaV + lambdaL));
}

// fast smith visibility
inline half VSmithFast(half a, half NdotV, half NdotL)
{
    return clampInfinite(0.5h / lerp(2.0h * NdotL * NdotV, NdotL + NdotV, a));
}

// neubelt visibility (for sheen specular)
inline half VNeubelt(half NdotV, half NdotL)
{
    return clampInfinite(0.25h / (NdotL + NdotV - NdotL * NdotV));
}

// cook-torrance specular brdf
inline half3 aSpecularBrdf(half3 f0, half a, half LdotH, half NdotH, half NdotL, half NdotV)
{
    half d = DGGX(a, NdotH);
    half v = VSmithFast(a, NdotV, NdotL);
    half3 f = FSchlick(f0, LdotH);
    return d * v * f;
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