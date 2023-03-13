#ifndef A_PASSES_DISTORT_CGINC
#define A_PASSES_DISTORT_CGINC

struct AVertexToFragment {
    A_VERTEX_DATA(0, 1, 2, 3, 4, 5, 6)
    float3 normalProjection : TEXCOORD7;
    float4 grabUv : TEXCOORD8;
    UNITY_FOG_COORDS(9)
};

#include "Assets/HSSSS/Framework/Pass.cginc"

void aVertexShader(AVertex v, out AVertexToFragment o, out float4 opos : SV_POSITION)
{
    aTransferVertex(v, o, opos);
    o.grabUv = ComputeGrabScreenPos(opos);
    o.normalProjection = mul((float3x3)UNITY_MATRIX_MVP, v.normal);
    UNITY_TRANSFER_FOG(o, opos);
}

sampler2D _GrabTexture;
sampler2D _CameraDepthTexture;
float4 _GrabTexture_TexelSize;
half _Absorption;

float _DistortWeight;
float _DistortIntensity;
float _DistortGeoWeight;

#define NUM_TAPS 16

const static float2 poissonDisk[NUM_TAPS] = {
	float2(0.176777, 0.000000),
    float2(-0.225780, 0.206818),
    float2(0.034587, -0.393769),
    float2(0.284530, 0.371204),
	float2(-0.522210, -0.092451),
    float2(0.494753, -0.314594),
    float2(-0.165602, 0.615488),
    float2(-0.315405, -0.607676),
	float2(0.684569, 0.250232),
    float2(-0.712353, 0.293773),
    float2(0.343624, -0.733602),
    float2(0.253403, 0.809035),
	float2(-0.764550, -0.443523),
    float2(0.897228, -0.196804),
    float2(-0.547908, 0.778490),
    float2(-0.125948, -0.976159)
};

inline float ComputeRefractionDepth(float2 uv, float depth)
{
    return LinearEyeDepth(tex2D(_CameraDepthTexture, uv)) - depth;
}

half4 aFragmentShader(AVertexToFragment i) : SV_Target
{
    ASurface s = aForwardSurface(i);

    float3 combinedNormals = BlendNormals(s.normalTangent, normalize(i.normalProjection));
    combinedNormals = lerp(s.normalTangent, combinedNormals, _DistortGeoWeight);

    float2 grabUv = i.grabUv.xy / i.grabUv.w;
    float depth = clamp(ComputeRefractionDepth(grabUv, s.viewDepth), 0.0f, 1.0f);
    float2 offset = depth * _DistortWeight * _DistortIntensity * combinedNormals.xy * _GrabTexture_TexelSize.xy;
    float2 offsetUv = (i.grabUv.xy - offset) / i.grabUv.w;

    float depthM = clamp(ComputeRefractionDepth(offsetUv, s.viewDepth), 0.0f, 1.0f);

    float2 uv = lerp(grabUv, offsetUv, depthM);
    half3 color = tex2D(_GrabTexture, uv).rgb;
    float depthS = clamp(ComputeRefractionDepth(uv, s.viewDepth), 0.0f, 1.0f);
    color = color * exp(-depthS * _Absorption * _SpecColor.rgb);
    color = color * mad(aFresnel(s.NdotV), -0.7h, 1.0h);
    return half4(color, 1.0h);
}

#endif