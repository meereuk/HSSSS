#ifndef HSSSS_MRT_CGINC
#define HSSSS_MRT_CGINC

#include "UnityCG.cginc"

struct appdata_mrt
{
    float4 pos: POSITION;
};

struct v2f_mrt
{
    float4 cpos: SV_POSITION;
    float2 uv: TEXCOORD0;
};

v2f_mrt vert_mrt(appdata_mrt v)
{
    v2f_mrt o;
    o.cpos = float4(v.pos.xy, 0.0, 1.0);
    o.uv = v.pos.xy * 0.5f + 0.5f;
    o.uv.y = _ProjectionParams.x < 0.0f ? 1.0f - o.uv.y : o.uv.y;
    return o;
}

#endif