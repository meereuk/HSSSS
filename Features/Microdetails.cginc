#ifndef HSSSS_FEATURES_MICRODETAILS
#define HSSSS_FEATURES_MICRODETAILS

#pragma exclude_renderers gles

#include "Assets/HSSSS/Framework/Surface.cginc"

float2 hash2D2D (float2 s)
{
	//magic numbers
	return frac(sin(fmod(float2(dot(s, float2(127.1,311.7)), dot(s, float2(269.5,183.3))), 3.14159))*43758.5453);
}

void GetStochasticUv(float2 uv, out float4x3 bw, out float2 dx, out float2 dy)
{
    //uv transformed into triangular grid space with UV scaled by approximation of 2*sqrt(3)
	float2 skewUV = mul(float2x2 (1.0 , 0.0 , -0.57735027 , 1.15470054), uv * 3.464);

    //vertex IDs and barycentric coords
	float2 vxID = float2(floor(skewUV));
	float3 barry = float3(frac(skewUV), 0);
	barry.z = 1.0 - (barry.x + barry.y);

    bw = ((barry.z > 0) ?
        float4x3(float3(vxID, 0), float3(vxID + float2(0, 1), 0), float3(vxID + float2(1, 0), 0), barry.zyx) :
		float4x3(float3(vxID + float2(1, 1), 0), float3(vxID + float2(1, 0), 0), float3(vxID + float2(0, 1), 0), float3(-barry.z, 1.0 - barry.y, 1.0 - barry.x)));
 
	//calculate derivatives to avoid triangular grid artifacts
	dx = ddx(uv);
	dy = ddy(uv);
}

float4 tex2DStochastic(sampler2D tex, float2 uv, float4x3 bw, float2 dx, float2 dy)
{
    return  mul(tex2D(tex, uv + hash2D2D(bw[0].xy), dx, dy), bw[3].x) + 
            mul(tex2D(tex, uv + hash2D2D(bw[1].xy), dx, dy), bw[3].y) + 
            mul(tex2D(tex, uv + hash2D2D(bw[2].xy), dx, dy), bw[3].z);
}

#if defined(_MICRODETAILS_ON)
    A_SAMPLER2D(_DetailNormalMap_2);
    A_SAMPLER2D(_DetailNormalMap_3);
    A_SAMPLER2D(_DetailSkinPoreMap);
    half _DetailNormalMapScale_2;
    half _DetailNormalMapScale_3;
    half _PoreOcclusionStrength;
#endif

inline void aSampleMicroTangent(inout ASurface s)
{
    #if defined(_MICRODETAILS_ON)
        half3 weight = abs(s.normalWorld) - 0.2h;
        weight = max(weight, 0.0h);
        weight = pow(weight, half3(3.0h, 3.0h, 3.0h));
        weight = weight / dot(weight, 1.0h);

        float3x2 uv = {
            A_TRANSFORM_SCROLL(_DetailSkinPoreMap, s.positionWorld.zy),
            A_TRANSFORM_SCROLL(_DetailSkinPoreMap, s.positionWorld.xz),
            A_TRANSFORM_SCROLL(_DetailSkinPoreMap, s.positionWorld.xy)
        };
        
        float4x3 bw0;
        float4x3 bw1;
        float4x3 bw2;

        float3x2 dx;
        float3x2 dy;

        GetStochasticUv(uv[0], bw0, dx[0], dy[0]);
        GetStochasticUv(uv[1], bw1, dx[1], dy[1]);
        GetStochasticUv(uv[2], bw2, dx[2], dy[2]);

        half3 pore = {
            tex2DStochastic(_DetailSkinPoreMap, uv[0], bw0, dx[0], dy[0]).r,
            tex2DStochastic(_DetailSkinPoreMap, uv[1], bw1, dx[1], dy[1]).r,
            tex2DStochastic(_DetailSkinPoreMap, uv[2], bw2, dx[2], dy[2]).r
        };

        half3 intensity = {
            _PoreOcclusionStrength,
            _DetailNormalMapScale_2,
            _DetailNormalMapScale_3
        };

        intensity *= pow(s.NdotV, 2);
        
        s.ambientOcclusion = s.ambientOcclusion * lerp(1.0h, dot(pore, weight), intensity.x);
        s.normalWorld = A_NORMAL_WORLD(s, s.normalTangent);

        half3x3 tangent;

        tangent[0] = UnpackScaleNormal(tex2DStochastic(_DetailNormalMap_2, uv[0], bw0, dx[0], dy[0]), intensity.y);
        tangent[1] = UnpackScaleNormal(tex2DStochastic(_DetailNormalMap_2, uv[1], bw1, dx[1], dy[1]), intensity.y);
        tangent[2] = UnpackScaleNormal(tex2DStochastic(_DetailNormalMap_2, uv[2], bw2, dx[2], dy[2]), intensity.y);

        tangent[0] = half3(0.0h, tangent[0].y, tangent[0].x);
        tangent[1] = half3(tangent[1].x, 0.0h, tangent[1].y);
        tangent[2] = half3(tangent[2].x, tangent[2].y, 0.0h);

        s.normalWorld = s.normalWorld + mul(weight, tangent);
        
        tangent[0] = UnpackScaleNormal(tex2DStochastic(_DetailNormalMap_3, uv[0], bw0, dx[0], dy[0]), intensity.z);
        tangent[1] = UnpackScaleNormal(tex2DStochastic(_DetailNormalMap_3, uv[1], bw1, dx[1], dy[1]), intensity.z);
        tangent[2] = UnpackScaleNormal(tex2DStochastic(_DetailNormalMap_3, uv[2], bw2, dx[2], dy[2]), intensity.z);

        tangent[0] = half3(0.0h, tangent[0].y, tangent[0].x);
        tangent[1] = half3(tangent[1].x, 0.0h, tangent[1].y);
        tangent[2] = half3(tangent[2].x, tangent[2].y, 0.0h);

        s.normalWorld = s.normalWorld + mul(weight, tangent);
        s.normalWorld = normalize(s.normalWorld);

        s.ambientNormalWorld = s.normalWorld;

        aUpdateViewData(s);
    #else
        aUpdateNormalData(s);
    #endif
}

#endif