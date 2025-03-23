sampler2D _MainTex;

float3 AgxDefaultContrastApprox(float3 x)
{
    float3 x2 = x * x;
    float3 x4 = x2 * x2;

    return  + 15.5f     * x4 * x2
            - 40.14f    * x4 * x
            + 31.96f    * x4
            - 6.868f    * x2 * x
            + 0.4298f   * x2
            + 0.1191f   * x
            - 0.00232f;
}

float3 Agx(float3 val) 
{
    float3x3 agx_mat = float3x3(
        0.8424790622530940f, 0.0423282422610123f, 0.0423756549057051f,
        0.0784335999999992f, 0.8784686364697720f, 0.0784336000000000f,
        0.0792237451477643f, 0.0791661274605434f, 0.8791429737931040f
        );

    // unity?
    float min_ev = -12.47393f;
    float max_ev =  0.526069f;

    // input transform
    val = mul(val, agx_mat);

    // log2 space encoding
    val = clamp(log2(val), min_ev, max_ev);
    val = (val - min_ev) / (max_ev - min_ev);

    // sigmoid approximation
    val = AgxDefaultContrastApprox(val);

    return val;
}

float3 AgxEotf(float3 val) 
{
    // Inverse input transform (outset)
    float3x3 agx_mat_inv = float3x3(
        1.1968790051201700f, -0.0528968517574562f, -0.0529716355144438f,
       -0.0980208811401368f,  1.1519031299041700f, -0.0980434501171241f,
       -0.0990297440797205f, -0.0989611768448433f,  1.1510736726411600f
    );
    
    val = mul(val, agx_mat_inv);

    return val;
}

float3 AgxLook(float3 val)
{
    float3 lw = float3(0.2126f, 0.7152f, 0.0722f);
    float luma = dot(val, lw);
    
    // default
    float3 offset = 0.0f;
    float3 slope = 1.0f;
    float3 power = 1.0f;
    float sat = 1.0f;
    
#if AGX_LOOK == 1
    // golden Look
    slope = float3(1.0f, 0.9f, 0.5f);
    power = float3(0.8f, 0.8f, 0.8f);
    sat = 0.8f;
#elif AGX_LOOK == 2
    // punchy Look
    slope = float3(1.00f, 1.00f, 1.00f);
    power = float3(1.35f, 1.35f, 1.35f);
    sat = 1.4f;
#endif

    // ASC CDL
    val = pow(val * slope + offset, power);
    return luma + sat * (val - luma);
}

half4 frag (v2f_img IN) : SV_Target
{
	half4 color = tex2D(_MainTex, IN.uv);
	color.xyz = Agx(color.xyz);
	color.xyz = AgxLook(color.xyz);
	color.xyz = AgxEotf(color.xyz);
	return color;
}