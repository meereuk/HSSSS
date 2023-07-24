Shader "Hidden/HSSSS/Deferred Reflections"
{
    Properties {
        _SrcBlend ("", Float) = 1
        _DstBlend ("", Float) = 1
    }

    SubShader {
        // Calculates reflection contribution from a single probe (rendered as cubes) or default reflection (rendered as full screen quad)
        Pass
        {
            ZWrite Off
            ZTest LEqual
            Blend [_SrcBlend] [_DstBlend]

            CGPROGRAM
            #pragma target 5.0
            #pragma only_renderers d3d11
            #pragma vertex vert_deferred
            #pragma fragment frag

            #include "Assets/HSSSS/Lighting/StandardSkin.cginc"
            #include "Assets/HSSSS/Framework/Deferred.cginc"

            half3 distanceFromAABB(half3 p, half3 aabbMin, half3 aabbMax)
            {
                return max(max(p - aabbMax, aabbMin - p), half3(0.0, 0.0, 0.0));
            }

            half4 frag (unity_v2f_deferred i) : SV_Target
            {
                ASurface s = aDeferredSurface(i);
                float blendDistance = unity_SpecCube1_ProbePosition.w; // will be set to blend distance for this probe

                if (s.scatteringMask > 0.1h && s.scatteringMask < 0.4h)
                {
                    half3 bitangent = normalize(half3(0.0h, 1.0h, 0.0h) - s.normalWorld * s.normalWorld.y);
                    half3 tangent = normalize(cross(s.normalWorld, bitangent));

                    half3 anisoTangent = cross(bitangent, s.viewDirWorld);
                    half3 anisoNormal = normalize(cross(anisoTangent, bitangent));

                    s.reflectionVectorWorld = reflect(-s.viewDirWorld, anisoNormal);
                }
    
                #if UNITY_SPECCUBE_BOX_PROJECTION
                    // For box projection, use expanded bounds as they are rendered; otherwise
                    // box projection artifacts when outside of the box.
                    float4 boxMin = unity_SpecCube0_BoxMin - float4(blendDistance,blendDistance,blendDistance,0);
                    float4 boxMax = unity_SpecCube0_BoxMax + float4(blendDistance,blendDistance,blendDistance,0);
                    half3 worldNormal0 = BoxProjectedCubemapDirection (s.reflectionVectorWorld, s.positionWorld, unity_SpecCube0_ProbePosition, boxMin, boxMax);
                #else
                    half3 worldNormal0 = s.reflectionVectorWorld;
                #endif

                Unity_GlossyEnvironmentData g;
                g.roughness = s.roughness;
                g.reflUVW = worldNormal0;

                half3 specular = Unity_GlossyEnvironment (UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, g);
                half3 rgb = specular * s.specularOcclusion * aEnvironmentBrdf(s.f0, s.roughness, s.NdotV);

                // Calculate falloff value, so reflections on the edges of the probe would gradually blend to previous reflection.
                // Also this ensures that pixels not located in the reflection probe AABB won't
                // accidentally pick up reflections from this probe.
                half3 distance = distanceFromAABB(s.positionWorld, unity_SpecCube0_BoxMin.xyz, unity_SpecCube0_BoxMax.xyz);
                half falloff = saturate(1.0 - length(distance) / blendDistance);
                return half4(rgb, falloff);
            }
            ENDCG
        }

        // Adds reflection buffer to the lighting buffer
        Pass
        {
            ZWrite Off
            ZTest Always
            Blend [_SrcBlend] [_DstBlend]

            CGPROGRAM
            #pragma target 5.0
            #pragma only_renderers d3d11
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile ___ UNITY_HDR_ON

            #include "UnityCG.cginc"

            sampler2D _CameraReflectionsTexture;

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
            };

            v2f vert (float4 vertex : POSITION)
            {
                v2f o;
                o.pos = mul(UNITY_MATRIX_MVP, vertex);
                o.uv = ComputeScreenPos (o.pos).xy;
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                return 0.0h;
            }
            ENDCG
        }
    }
    
    Fallback Off
}
