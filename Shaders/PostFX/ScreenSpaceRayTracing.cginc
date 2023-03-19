#ifndef HSSSS_SSRT_CGINC
#define HSSSS_SSRT_CGINC

#include "UnityCG.cginc"

// vertex input
struct appdata
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
};

// fragment input
struct v2f
{
    float2 uv : TEXCOORD0;
    float4 vertex : SV_POSITION;
};

// vertex shader
v2f vert (appdata v)
{
    v2f o;
    o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
    o.uv = v.uv;
    return o;
}

sampler2D _MainTex;
float4 _MainTex_TexelSize;
// albedo and occlusion
sampler2D _CameraGBufferTexture0;
// specular and roughness
sampler2D _CameraGBufferTexture1;
// world space normal
sampler2D _CameraGBufferTexture2;
// light buffer
sampler2D _CameraGBufferTexture3;
// depth
sampler2D _CameraDepthTexture;
// jittering
sampler2D _ShadowJitterTexture;
float4 _ShadowJitterTexture_TexelSize;

float4x4 _MATRIX_V;
float4x4 _MATRIX_P;
float4x4 _MATRIX_VP;

float4x4 _MATRIX_IV;
float4x4 _MATRIX_IP;
float4x4 _MATRIX_IVP;

#define NUM_STEP 32
#define NUM_RAYS 32
#define MAX_RAYS 128
#define RAY_DIST 2.0

#define NUM_TAPS 17

const static float2 blurKernel[NUM_TAPS] = {
    float2(0.536343, 0),
    float2(0.00317394, -2),
    float2(0.0100386, -1.53125),
    float2(0.0144609, -1.125),
    float2(0.0216301, -0.78125),
    float2(0.0347317, -0.5),
    float2(0.0571056, -0.28125),
    float2(0.0582416, -0.125),
    float2(0.0324462, -0.03125),
    float2(0.0324462, 0.03125),
    float2(0.0582416, 0.125),
    float2(0.0571056, 0.28125),
    float2(0.0347317, 0.5),
    float2(0.0216301, 0.78125),
    float2(0.0144609, 1.125),
    float2(0.0100386, 1.53125),
    float2(0.00317394, 2),
};

//ray information
struct ray
{
    bool hit;
    float len;
    float3 dir;
    float2 uv;
};

const static half3 hemiSphere[MAX_RAYS] = 
{
    {-0.36377122, -0.06466426, 0.92924111}, {-0.63739404, 0.77042056, 0.01345376}, {0.60077177, -0.64382270, 0.47388354}, {-0.89508176, -0.44167590, 0.06124570},
    {-0.45985219, 0.76272082, 0.45474489}, {0.81002494, -0.28325865, 0.51344340}, {0.69173731, -0.69055395, 0.21126936}, {-0.64019846, -0.52778151, 0.55820482},
    {-0.52398504, -0.76928204, 0.36557466}, {0.05657133, 0.91146387, 0.40747183}, {-0.47115422, 0.70370697, 0.53179903}, {-0.38340030, 0.57773724, 0.72057192},
    {0.35554976, 0.58166295, 0.73160958}, {0.79211300, 0.42279663, 0.44022723}, {-0.52535336, -0.56865612, 0.63295661}, {0.71373064, 0.51263901, 0.47727332},
    {0.58348705, -0.74160535, 0.33100509}, {0.41435268, 0.18669676, 0.89076157}, {0.45995542, -0.63126694, 0.62445421}, {0.78821755, 0.56910006, 0.23417561},
    {-0.81530577, -0.14261423, 0.56119309}, {-0.65338776, 0.73793339, 0.16893418}, {0.73556071, -0.20534770, 0.64558715}, {0.32630075, -0.22461428, 0.91819183},
    {-0.26693155, 0.96365505, 0.01079320}, {-0.64634891, 0.57081166, 0.50636661}, {-0.69247260, 0.24768752, 0.67759323}, {-0.87660624, -0.47961190, 0.03916551},
    {-0.28475698, -0.69647928, 0.65865778}, {-0.54144468, 0.55878095, 0.62817316}, {0.47974654, 0.33977122, 0.80894918}, {-0.06421279, -0.60365398, 0.79465627},
    {-0.43644993, -0.69641724, 0.56966173}, {-0.24247742, -0.78397566, 0.57147780}, {-0.25211252, -0.82858368, 0.49988834}, {0.69368076, -0.00923879, 0.72022334},
    {0.80216932, 0.55906113, 0.20970225}, {-0.17712500, 0.48296773, 0.85753653}, {0.66189856, -0.36419424, 0.65517390}, {0.49781454, 0.84060406, 0.21346076},
    {0.08567333, 0.36285868, 0.92789744}, {-0.35049013, -0.61392953, 0.70728155}, {-0.86141720, -0.49685282, 0.10534555}, {0.64211269, 0.58115636, 0.49994858},
    {0.75747950, -0.12093747, 0.64155976}, {0.16240349, -0.96432303, 0.20906027}, {0.61869358, 0.19409326, 0.76127922}, {0.17762002, 0.94171383, 0.28570297},
    {0.56903969, -0.61581271, 0.54494820}, {0.46577258, 0.61427564, 0.63696259}, {-0.52051678, -0.80440826, 0.28633830}, {0.03463963, -0.87473185, 0.48336766},
    {-0.21101173, -0.68659876, 0.69574147}, {0.14695680, 0.50750811, 0.84902250}, {0.72296787, 0.07633601, 0.68665149}, {-0.79289671, 0.46983191, 0.38803709},
    {-0.49660117, -0.62576008, 0.60150777}, {-0.12982466, 0.89974762, 0.41665307}, {-0.19557077, 0.23699255, 0.95162314}, {-0.56069172, 0.53878429, 0.62875774},
    {0.28245099, -0.31301333, 0.90677676}, {-0.51213830, 0.34945303, 0.78459986}, {-0.54348164, 0.58757888, 0.59948208}, {0.09138109, 0.29190665, 0.95207143},
    {-0.87762342, 0.47718562, 0.04550832}, {0.83260049, 0.12688630, 0.53914403}, {0.36738714, 0.14216877, 0.91913804}, {-0.08808037, -0.50745303, 0.85716584},
    {0.75631326, 0.12666801, 0.64182978}, {-0.90198766, -0.43163978, 0.01026447}, {0.39702735, 0.58569954, 0.70662956}, {0.56906582, -0.53386812, 0.62541900},
    {0.06705044, 0.65935053, 0.74883985}, {0.29393394, 0.75332623, 0.58830470}, {-0.19225213, -0.56895936, 0.79957762}, {0.57090968, 0.29684957, 0.76546879},
    {0.65043564, 0.16300083, 0.74186536}, {-0.58370128, -0.75349174, 0.30256075}, {0.62719085, 0.50930260, 0.58927286}, {0.42288222, 0.67888331, 0.60024002},
    {0.69051304, -0.44426596, 0.57080601}, {0.76774345, -0.36156797, 0.52899773}, {0.66613275, 0.73481632, 0.12771899}, {0.75213437, -0.55498774, 0.35536249},
    {-0.93332320, 0.25660951, 0.25111624}, {-0.09638068, -0.70571080, 0.70191384}, {0.50270775, -0.63833266, 0.58293768}, {0.82089572, -0.51387630, 0.24912119},
    {-0.88972253, 0.45617873, 0.01716945}, {-0.14917571, 0.56730690, 0.80988239}, {0.81598313, 0.37544123, 0.43956276}, {0.28275056, 0.23774966, 0.92926165},
    {-0.93954688, 0.20347894, 0.27540512}, {0.91338471, 0.19405525, 0.35786998}, {0.21086505, -0.39999405, 0.89193088}, {0.09782343, -0.73507708, 0.67088915},
    {0.19708850, -0.71057373, 0.67545622}, {0.40169114, 0.32274226, 0.85701906}, {-0.76898692, 0.55790316, 0.31209482}, {-0.60602515, 0.69896203, 0.37971778},
    {-0.58776332, -0.47407379, 0.65558242}, {0.55098993, -0.48624949, 0.67821200}, {0.29929044, 0.93304682, 0.19962180}, {-0.57699974, -0.64267389, 0.50402536},
    {0.63977030, 0.33228547, 0.69302260}, {0.35164234, 0.76092706, 0.54528678}, {0.65508826, -0.54163508, 0.52677396}, {-0.76974942, 0.00263364, 0.63834074},
    {-0.88295729, -0.43683659, 0.17193083}, {-0.20286039, 0.83609814, 0.50969359}, {-0.47474297, 0.69695272, 0.53747188}, {-0.38794594, 0.82820060, 0.40445235},
    {-0.71627907, -0.69369540, 0.07570332}, {-0.44989168, -0.22093088, 0.86532481}, {-0.92016223, 0.09829721, 0.37899752}, {0.93019557, -0.21041566, 0.30076810},
    {0.55602062, 0.48924272, 0.67192458}, {0.37786698, 0.26657914, 0.88665219}, {-0.20676029, 0.07680973, 0.97537195}, {0.09469667, 0.99505521, 0.02996125},
    {0.36967618, 0.75609121, 0.54006073}, {0.43545358, 0.74479202, 0.50563328}, {-0.42502002, 0.64291418, 0.63719647}, {-0.38157252, -0.86079804, 0.33679243},
    {-0.26679593, -0.25411146, 0.92964902}, {0.70640857, -0.35919189, 0.60989190}, {-0.29454581, 0.92986161, 0.22045444}, {-0.71873742, 0.37604540, 0.58481312}
};

inline float3 SamplePositionWorld(float2 uv)
{
    float depth = tex2D(_CameraDepthTexture, uv);
    float4 spos = float4(mad(uv, 2.0f, -1.0f), depth, 1.0f);
    float4 wpos = mul(_MATRIX_IVP, spos);
    return wpos.xyz / wpos.w;
}

inline float3 SampleNormalWorld(float2 uv)
{
    return normalize(mad(tex2D(_CameraGBufferTexture2, uv).rgb, 2.0f, -1.0f));
}

inline float3 SampleAlbedoBuffer(float2 uv)
{
    return tex2D(_CameraGBufferTexture0, uv).rgb;
}

inline float3 SampleLightBuffer(float2 uv)
{
    return tex2D(_MainTex, uv).rgb + tex2D(_CameraGBufferTexture3, uv).rgb;
}

inline void RayTraceIteration(float3 pos, inout ray ray)
{
    float3 stride = ray.dir * RAY_DIST / NUM_STEP;

    [unroll]
    for (uint iter = 1; iter <= NUM_STEP; iter ++)
    {
        float4 wpos = float4(pos + stride * iter, 1.0f);

        float4 vpos = mul(_MATRIX_V, wpos);
        float4 cpos = mul(_MATRIX_VP, wpos);

        float2 uv = mad(cpos.xy / cpos.w, 0.5f, 0.5f);

        float rayDepth = -vpos.z;
        float refDepth = LinearEyeDepth(tex2D(_CameraDepthTexture, uv));

        float zDiff = rayDepth - refDepth;

        if (zDiff > 0.01f && zDiff < 1.0f)
        {
            ray.hit = true;
            ray.len = dot(stride * iter, stride * iter);
            ray.uv = uv;
            return;
        }
    }
}

inline half3 ComputeIndirectLight(float2 uv)
{
    /*
    float3 jitter = normalize(mad(tex2D(_ShadowJitterTexture,
        uv * _ScreenParams.xy * _ShadowJitterTexture_TexelSize.xy + _Time.yy), 2.0f, -1.0f));
        */

    float3 jitter = float3(
        frac(sin(dot(uv + _Time.xx, 1.0f * float2(12.9898, 78.233))) * 43758.5453123),
        frac(sin(dot(uv + _Time.yy, 2.0f * float2(12.9898, 78.233))) * 43758.5453123),
        frac(sin(dot(uv + _Time.zz, 3.0f * float2(12.9898, 78.233))) * 43758.5453123)
    );

    jitter = normalize(mad(jitter, 2.0f, -1.0f));

    float3 albedo = SampleAlbedoBuffer(uv);
    half3 normal = SampleNormalWorld(uv);
    half3 wcoord = SamplePositionWorld(uv);

    float3 tangent = normalize(jitter - normal * dot(jitter, normal));
    float3 bitangent = normalize(cross(normal, tangent));

    float3x3 tbn = float3x3(tangent, bitangent, normal);

    half3 indirect = 0.0h;

    uint offset = 64 * uint(frac(sin(dot(uv + _Time.xx, float2(12.9898, 78.233))) * 43758.5453123));

    for(uint iter = 0; iter < NUM_RAYS; iter ++)
    {
        ray ray;

        ray.dir = normalize(mul(hemiSphere[iter], tbn));
        ray.hit = false;
        ray.len = 1.0h;
        ray.uv = uv;

        RayTraceIteration(wcoord, ray);

        if (ray.hit && ray.len > 0.01h)
        {
            half3 refLight = SampleLightBuffer(ray.uv);
            half3 refNormal = SampleNormalWorld(ray.uv);

            half ndotl = saturate(dot(ray.dir, normal));
            half ndotn = dot(refNormal, normal);
            half atten = 0.25h / max(ray.len, 1.0h);

            indirect += ndotl * atten * refLight * albedo;
        }
    }

    return indirect / NUM_RAYS;
}

half4 BlurInDir(float2 uv, float2 dir)
{
    half4 colorM = tex2D(_MainTex, uv);
	half depthM = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));

    float scale = 64.0f * unity_CameraProjection._m11 / depthM;
	float2 finalStep = scale * dir * dot(dir, _MainTex_TexelSize.xy);

    half4 colorB = colorM * blurKernel[0].x;
	
	[unroll]
	for (int i = 1; i < NUM_TAPS; i++)
	{
		float2 offsetUv = uv + finalStep * blurKernel[i].y;
        half4 color = tex2D(_MainTex, offsetUv);
        half depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, offsetUv));
        half s = min(1.0f, 4.0 * abs(depth - depthM));
        colorB += lerp(color, colorM, s) * blurKernel[i].x;
	}
        
	return colorB;
}

#endif