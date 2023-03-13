#ifndef A_LIGHTING_HAIR_CGINC
#define A_LIGHTING_HAIR_CGINC

#define A_AREA_SPECULAR_OFF

#define A_SURFACE_CUSTOM_LIGHTING_DATA \
    half diffuseWrap; \
    half3 highlightTangent; \
    half3 highlightTangentWorld; \
    half3 highlightTint; \
    half highlightShift; \
    half highlightWidth;
    
#include "Assets/HSSSS/Framework/Lighting.cginc"

half3 aKajiyaKay(ADirect d, ASurface s)
{
    half a = aLinearToBeckmannRoughness(s.roughness);
    half sp = (2.0h / (a * a)) - 2.0h;

    half tdhm = dot(normalize(s.highlightTangentWorld + s.normalWorld * s.highlightShift), d.halfAngleWorld);
    half spec = (sp * 0.125h + 0.25h) * pow(sqrt(1.0h - tdhm * tdhm), sp);

    return s.f0 * spec;
}

void aPreSurface(inout ASurface s)
{
    s.diffuseWrap = 0.25h;
    s.highlightTangent = half3(0.0h, 1.0h, 0.0h);
    s.highlightTint = half3(1.0h, 1.0h, 1.0h);
    s.highlightShift = 0.0h;
    s.highlightWidth = 0.25h;
}

void aPostSurface(inout ASurface s)
{
    s.highlightTangentWorld = A_NORMAL_WORLD(s, s.highlightTangent);
    s.ambientNormalWorld = s.normalWorld;

    s.roughness = lerp(s.roughness, 1.0h, s.highlightWidth);
    s.f0 = s.f0 * s.highlightTint;
}

void aDirect(ADirect d, ASurface s, out half3 diffuse, out half3 specular)
{
    half denom = (1.0h + s.diffuseWrap);
    diffuse = d.color * d.shadow.r * s.albedo * saturate((d.NdotLm + s.diffuseWrap) / (denom * denom));
    specular = d.color * d.shadow.r * (s.specularOcclusion * d.specularIntensity * d.NdotL) * aKajiyaKay(d, s);
}

half3 aIndirect(AIndirect i, ASurface s)
{	
    half3 ambient = i.diffuse * s.ambientOcclusion;
    return ambient * s.albedo + s.f0 * lerp(ambient, i.specular, s.specularOcclusion);
}

#endif