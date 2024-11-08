cbuffer cbMain : register( b0 )
{
	matrix    g_mWorld;                         // World matrix
	matrix    g_mView;                          // View matrix
	matrix    g_mProjection;                    // Projection matrix
	matrix    g_mWorldViewProjection;           // WVP matrix
	matrix    g_mWorldView;                     // WV matrix
	matrix    g_mInvView;                       // Inverse of view matrix

	matrix    g_mObject1;                // VP matrix
	matrix    g_mObject1WorldView;                       // Inverse of view matrix
	matrix    g_mObject1WorldViewProjection;                       // Inverse of view matrix

	matrix    g_mObject2;                // VP matrix
	matrix    g_mObject2WorldView;                       // Inverse of view matrix
	matrix    g_mObject2WorldViewProjection;                       // Inverse of view matrix

	float4    g_vFrustumNearFar;              // Screen resolution
	float4    g_vFrustumParams;              // Screen resolution
	float4    g_viewLightPos;                   //

    float4    g_time;  
};

Texture2D colorMap  : register( t0 );
TextureCube  skyboxMap : register( t1 );
Texture3D noiseMap  : register( t2 );
SamplerState defaultSampler : register( s0 );

float3 turbulence ( const in float3 p, const in float freqScale )
{
    float sum = 0.0;
    float3  t   = float3 ( 0.0, 0.0, 0.0 );
    float f   = 1.0;

    for ( int i = 0; i <= 3; i++ )
    {
        t   += abs ( 2.0 * noiseMap.Sample(defaultSampler, f * p.xyz ).rgb - float3 ( 1.0, 1.0, 1.0 ) ) / f;
        sum += 1.0 / f;
        f   *= freqScale;
    }
                                 // remap from [0,sum] to [-1,1]
    return 2.0 * t / sum - float3 ( 1.0, 1.0, 1.0  );
}

float4 MODEL_FRAG(
    float3 normal         : TEXCOORD0,
    float2 tex            : TEXCOORD1,
	float3 world_pos      : TEXCOORD2,
    float4 clip_pos       : SV_POSITION
):SV_TARGET
{ 
   float3 view_pos = g_mInvView._m30_m31_m32;
   float3 v = view_pos - world_pos;

   const float4 c2 = 2.2 * float4 ( 0.03, 0.15, 0.125, 1.0 );
   const float4 c1 = 1.6 * float4 ( 0.03, 0.2,  0.07, 1.0 );
   
   float3 arg = 0.05*world_pos + float3 ( 0.04101, -0.0612149, 0.071109 ) * g_time.x * 5.0 * 0.7;
   float3 ns  = float3 ( turbulence ( arg, 2.17 ).xy, 1.0 );

   float3 en  = normalize ( v );
   float3 nn  = normalize ( normal + 0.1 * ns );
   float3 r   = -reflect   ( en, nn );

   float4 envColor = saturate(skyboxMap.Sample(defaultSampler, r));

   float fresnel = clamp ( abs ( dot ( en, nn ) ), 0.1, 0.9 );

   float4 fragColor = float4 ( lerp ( c1, c2, abs ( dot ( en, nn ) ) ) * fresnel +  (1.0-fresnel) * envColor );
    
   return fragColor;//colorMap.Sample( defaultSampler, tex.xy);
};

float4 SKYBOX_FRAG(
    float3 tex : TEXCOORD0
):SV_TARGET
{
	float4 color = saturate(skyboxMap.Sample(defaultSampler, tex));

	return float4(color.xyz, 1);
}