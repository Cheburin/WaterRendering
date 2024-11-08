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

struct PosNormalTex2d
{
    float3 pos : SV_Position;
    float3 normal   : NORMAL;
    float2 tex      : TEXCOORD0;
};

struct ClipPosNormalTex2dWorldPos
{
    float3 normal         : TEXCOORD0;   // Normal vector in world space
    float2 tex            : TEXCOORD1;
	float3 world_pos      : TEXCOORD2;
    float4 clip_pos       : SV_POSITION; // Output position
};

struct ClipPosTex3d
{
    float3 tex            : TEXCOORD0;
    float4 clip_pos       : SV_POSITION; // Output position
};

struct ExpandPos
{
    float4 pos      : SV_POSITION;
};

///////////////////////////////////////////////////////////////////////////////////////////////////
ExpandPos SIMPLE_THROWPUT(uint VertexID : SV_VERTEXID)
{
  ExpandPos output;  
  
  output.pos =  float4( 0, 0, 0, 1.0 );

  return output;
}   
///////////////////////////////////////////////////////////////////////////////////////////////////
static const float4 cubeVerts[8] = 
{
	float4(-0.5, -0.5, -0.5, 1),// LB  0
	float4(-0.5, 0.5, -0.5, 1), // LT  1
	float4(0.5, -0.5, -0.5, 1), // RB  2
	float4(0.5, 0.5, -0.5, 1),  // RT  3
	float4(-0.5, -0.5, 0.5, 1), // LB  4
	float4(-0.5, 0.5, 0.5, 1),  // LT  5
	float4(0.5, -0.5, 0.5, 1),  // RB  6
	float4(0.5, 0.5, 0.5, 1)    // RT  7
};

static const int cubeIndices[24] =
{
	0, 1, 2, 3, // front
	7, 6, 3, 2, // right
	7, 5, 6, 4, // back
	4, 0, 6, 2, // bottom
	1, 0, 5, 4, // left
	3, 1, 7, 5  // top
};

[maxvertexcount(36)]
void SKYBOX_GS(point ExpandPos pnt[1], uint primID : SV_PrimitiveID,  inout TriangleStream<ClipPosTex3d> triStream )
{
	ClipPosTex3d v[8];
	[unroll]
	for (int j = 0; j < 8; j++)
	{
		v[j].clip_pos = mul(cubeVerts[j], g_mWorldViewProjection);
		v[j].tex = cubeVerts[j].xyz;
	}
	
	[unroll]
	for (int i = 0; i < 6; i++)
	{
		triStream.Append(v[cubeIndices[i * 4 + 1]]);
		triStream.Append(v[cubeIndices[i * 4 + 2]]);
		triStream.Append(v[cubeIndices[i * 4]]);
		triStream.RestartStrip();
		
		triStream.Append(v[cubeIndices[i * 4 + 3]]);
		triStream.Append(v[cubeIndices[i * 4 + 2]]);
		triStream.Append(v[cubeIndices[i * 4 + 1]]);
		triStream.RestartStrip();
	}
}
///////////////////////////////////////////////////////////////////////////////////////////////////

float3 turbulence ( const in float3 p, const in float freqScale )
{
    float sum = 0.0;
    float3  t   = float3 ( 0.0, 0.0, 0.0 );
    float f   = 1.0;

    for ( int i = 0; i <= 3; i++ )
    {
        t   += abs ( 2.0 * noiseMap.SampleLevel(defaultSampler, f * p.xyz, 0 ).rgb - float3 ( 1.0, 1.0, 1.0 ) ) / f;
        sum += 1.0 / f;
        f   *= freqScale;
    }
                                        // remap from [0,sum] to [0,1]
    return t / sum;
}

ClipPosNormalTex2dWorldPos MODEL_VERTEX( in PosNormalTex2d i )
{
    //////
    const float3 dx  = float3 ( 0.01, 0.0,  0.0 );
    const float3 dy  = float3 ( 0.0,  0.01, 0.0 );
    const float3 vel = float3 ( 0.02, 0.01, 0.0 );
	
                                        // compute height and delta height (in dx and dy)
    float3 tex    = float3     ( i.pos.xz, 0.09 * g_time.x ) + vel * g_time.x;
    float3 turb   = turbulence ( tex,      2.0 );
    float3 turbX  = turbulence ( tex + dx, 2.0 );
    float3 turbY  = turbulence ( tex + dy, 2.0 );
    float3 n      = float3     ( turbX.x - turb.x, turbY.x - turb.x, 0.8 );
	//////

    ClipPosNormalTex2dWorldPos output;

    output.normal = float3( normalize ( float3(0,1,0) ) );	

    output.tex = i.pos.xz;

	output.world_pos = mul( float4( i.pos - float3(0.5f, 0.05 * turb.x, 0.5f), 1.0 ), g_mWorld ).xyz;

    output.clip_pos = mul( float4( i.pos - float3(0.5f, 0.05 * turb.x, 0.5f), 1.0 ), g_mWorldViewProjection );
    
    return output;
}; 