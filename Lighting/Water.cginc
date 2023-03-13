#ifndef A_LIGHTING_STANDARD_CGINC
#define A_LIGHTING_STANDARD_CGINC

#include "Assets/HSSSS/Framework/Lighting.cginc"

sampler2D _GrabTexture;
sampler2D _CameraDepthTexture;

half3 _TransColor;
half _TransScale;
half _TransPower;
half _TransDistortion;
half _DistortWeight;
half _Absorption;

inline float RefractionDepth(float2 uv, float depth)
{
    return LinearEyeDepth(tex2D(_CameraDepthTexture, uv)) - depth;
}

void aPreSurface(inout ASurface s)
{
}

void aPostSurface(inout ASurface s)
{
    //s.ambientNormalWorld = s.normalWorld;
}

inline float4 GetScreenPos(float4 vec)
{
    return ComputeScreenPos(mul(UNITY_MATRIX_P, vec));
}

inline half3 ScreenSpaceRefraction(ASurface s)
{
    float4 rayTail = mul(UNITY_MATRIX_V, float4(s.positionWorld, 1.0f));
    float4 rayHead = mul(UNITY_MATRIX_V, float4(s.positionWorld - normalize(lerp(s.viewDirWorld, s.normalWorld, _DistortWeight)), 1.0f));

    float4 refPosition = ComputeScreenPos(mul(UNITY_MATRIX_P, rayTail));

    [unroll]
    for (int iter = 0; iter < 32; iter ++)
    {
        float4 rayPosition = lerp(rayTail, rayHead, float(iter) / 32.0f);
        float4 scrPosition = ComputeScreenPos(mul(UNITY_MATRIX_P, rayPosition));

        float rayDepth = -rayPosition.z;
        float refDepth = LinearEyeDepth(tex2Dproj(_CameraDepthTexture, scrPosition).r);

        if (rayDepth < refDepth)
        {
            refPosition = scrPosition;
        }
    }

    return tex2Dproj(_GrabTexture, refPosition);

    //return refPosition.z;

    //float z = max(LinearEyeDepth(tex2Dproj(_CameraDepthTexture, refPosition).r) - s.viewDepth, 0.0f);
    //return tex2Dproj(_GrabTexture, refPosition) * exp(-z * _Absorption * _SpecColor);
}

inline half3 ScreenSpaceReflection(ASurface s)
{
    float4 rayTail = mul(UNITY_MATRIX_V, float4(s.positionWorld, 1.0f));
    float4 rayHead = mul(UNITY_MATRIX_V, float4(s.positionWorld + reflect(-s.viewDirWorld, s.normalWorld), 1.0f));

    float4 refPosition = ComputeScreenPos(mul(UNITY_MATRIX_P, rayHead));

    [unroll]
    for (int iter = 0; iter < 32; iter ++)
    {
        float4 rayPosition = lerp(rayTail, rayHead, float(iter) / 32.0f);
        float4 scrPosition = ComputeScreenPos(mul(UNITY_MATRIX_P, rayPosition));

        float rayDepth = -rayPosition.z;
        float refDepth = LinearEyeDepth(tex2Dproj(_CameraDepthTexture, scrPosition).r);

        if (rayDepth > refDepth)
        {
            return tex2Dproj(_GrabTexture, scrPosition);
        }
    }

    return 0.0h;
}

void aDirect(ADirect d, ASurface s, out half3 diffuse, out half3 specular)
{
    aStandardDirect(d, s, diffuse, specular);

    half3 direction = normalize(_TransDistortion * s.normalWorld + d.direction);
    half transmission = pow(saturate(dot(s.viewDirWorld, -direction)), _TransPower);

    #if defined(UNITY_PASS_FORWARDBASE)
        // refraction
        half3 refraction = ScreenSpaceRefraction(s);
        diffuse = lerp(refraction, diffuse, s.opacity);

        half3 reflection = ScreenSpaceReflection(s);
        specular = 0.0h;//specular + reflection * 0.2h;
    #else
        diffuse = 0.0h;
    #endif

    diffuse = diffuse + transmission * d.color * _TransColor * _TransScale;
}

half3 aIndirect(AIndirect i, ASurface s)
{
    return 0.0h;
    //return aStandardIndirect(i, s);
}

#endif