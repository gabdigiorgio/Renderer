#define FLT_MAX 3.40282347e+38
#define NUM_SPHERES 5

float4x4 InverseView;
float4x4 InverseProjection;
float3 CameraPosition;

float ViewportWidth;
float ViewportHeight;

int MaxBounceCount;
int NumRaysPerPixel;
int Frame;
int NumRenderedFrames;

texture Texture;
sampler2D textureSampler = sampler_state
{
    Texture = (Texture);
    MagFilter = Linear;
    MinFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

texture OldTexture;
sampler2D oldTextureSampler = sampler_state
{
    Texture = (OldTexture);
    MagFilter = Linear;
    MinFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

struct Sphere
{
    float3 Position;
    float Radius;
    float4 Color;
    float4 EmissionColor;
    float EmissionStrength;
};

struct Ray
{
    float3 Origin;
    float3 Dir;
};

struct HitInfo
{
    bool DidHit;
    float Distance;
    float3 HitPoint;
    float3 Normal;
    float4 Color;
    float4 EmissionColor;
    float EmissionStrength;
};

static Sphere spheres[NUM_SPHERES] =
{
    {
        float3(-100.0f, 135.0f, -40.0f), // Position
        30.0f, // Radius
        float4(0.0f, 1.0f, 0.0f, 1.0f), // Color
        float4(0.0f, 0.0f, 0.0f, 0.0f), // Emission color (default)
        0.0f // Emission strength (default)
    },
    {
        float3(-50.0f, 150.0f, 100.0f), // Position
        20.0f, // Radius
        float4(1.0f, 0.0f, 0.0f, 1.0f), // Color
        float4(0.0f, 0.0f, 0.0f, 0.0f), // Emission color (default)
        0.0f // Emission strength (default)
    },
    {
        float3(50.0f, 130.0f, 0.0f), // Position
        25.0f, // Radius
        float4(0.0f, 0.0f, 1.0f, 1.0f), // Color
        float4(0.0f, 0.0f, 0.0f, 0.0f), // Emission color (default)
        0.0f // Emission strength (default)
    },
    {
        // LIGHT
        float3(350.0f, 120.0f, 0.0f), // Position
        120.0f,
        float4(1.0f, 1.0f, 1.0f, 1.0f), // Color
        float4(1.0f, 1.0f, 1.8f, 1.0f), // Emission color
        10.0f // Emission strength
    },
    {
        float3(0.0f, 600.0f, 0.0f), // Position
        450.0f,
        float4(0.5f, 0.0f, 0.5f, 1.0f), // Color
        float4(0.0f, 0.0f, 0.0f, 0.0f), // Emission color (default)
        0.0f // Emission strength (default)
    }
};

// https://www.shadertoy.com/view/XlGcRh
uint NextRandom(inout uint state)
{
    state = state * 747796405 + 2891336453;
    uint result = ((state >> ((state >> 28) + 4)) ^ state) * 277803737;
    result = (result >> 22) ^ result;
    return result;
}

float RandomValue(inout uint state)
{
    return NextRandom(state) / 4294967295.0;
}

// https://stackoverflow.com/a/6178290
float RandomValueNormalDistribution(inout uint state)
{
    float theta = 2 * 3.1415926 * RandomValue(state);
    float rho = sqrt(-2 * log(RandomValue(state)));
    return rho * cos(theta);
}

// https://math.stackexchange.com/a/1585996
float3 RandomDirection(inout uint state)
{
    float x = RandomValueNormalDistribution(state);
    float y = RandomValueNormalDistribution(state);
    float z = RandomValueNormalDistribution(state);
    return normalize(float3(x, y, z));
}

float3 RandomHemisphereDirection(float3 normal, inout uint rngState)
{
    float3 dir = RandomDirection(rngState);
    return dir * sign(dot(normal, dir));
}

HitInfo RaySphere(Ray ray, float3 sphereCenter, float sphereRadius)
{
    HitInfo hitInfo = (HitInfo) 0;
    
    float3 offsetRayOrigin = ray.Origin - sphereCenter;
    float a = dot(ray.Dir, ray.Dir);
    float b = 2 * dot(offsetRayOrigin, ray.Dir);
    float c = dot(offsetRayOrigin, offsetRayOrigin) - sphereRadius * sphereRadius;
    
    float discriminant = b * b - 4 * a * c;
    
    if (discriminant >= 0)
    {
        float distance = (-b - sqrt(discriminant)) / (2 * a);
        
        if (distance >= 0)
        {
            hitInfo.DidHit = true;
            hitInfo.Distance = distance;
            hitInfo.HitPoint = ray.Origin + ray.Dir * distance;
            hitInfo.Normal = normalize(hitInfo.HitPoint - sphereCenter);
        }
    }
    
    return hitInfo;
}

HitInfo CalculateRayCollision(Ray ray)
{
    HitInfo closestHit = (HitInfo) 0;
    
    // Haven't hit anything, closest hit is infinitely far away
    closestHit.Distance = FLT_MAX;
    
    for (int i = 0; i < NUM_SPHERES; i++)
    {
        Sphere sphere = spheres[i];
        HitInfo hitInfo = RaySphere(ray, sphere.Position, sphere.Radius);
        
        if (hitInfo.DidHit && hitInfo.Distance < closestHit.Distance)
        {
            closestHit = hitInfo;
            closestHit.Color = sphere.Color;
            closestHit.EmissionColor = sphere.EmissionColor;
            closestHit.EmissionStrength = sphere.EmissionStrength;
        }
    }

    return closestHit;
}

float3 Trace(Ray ray, inout uint rngState)
{
    float3 incomingLight = 0;
    float3 rayColor = 1;
    
    for (int i = 0; i <= MaxBounceCount; i++)
    {
        HitInfo hitInfo = CalculateRayCollision(ray);
        if (hitInfo.DidHit)
        {
            ray.Origin = hitInfo.HitPoint;
            ray.Dir = RandomHemisphereDirection(hitInfo.Normal, rngState);
            
            float3 emittedLight = hitInfo.EmissionColor * hitInfo.EmissionStrength;
            incomingLight += emittedLight * rayColor;
            rayColor *= hitInfo.Color;
        }
        else
        {
            break;
        }
    }

    return incomingLight;
}

struct VertexShaderInput
{
    float4 Position : POSITION0;
    float2 TextureCoordinates : TEXCOORD0;
};
 
struct VertexShaderOutput
{
    float4 Position : SV_POSITION;
    float2 TextureCoordinates : TEXCOORD0;
};
 
VertexShaderOutput MainVS(VertexShaderInput input)
{
    VertexShaderOutput output = (VertexShaderOutput) 0;
 
    output.Position = input.Position;
    output.TextureCoordinates = input.TextureCoordinates;
 
    return output;
}
 
float4 RayTracingPS(VertexShaderOutput input) : COLOR0
{
    float2 uv = input.TextureCoordinates;
    
    // Seed for random numbers
    uint2 numpixels = uint2(ViewportWidth, ViewportHeight);
    uint2 pixelCoord = uv * numpixels;
    uint pixelindex = pixelCoord.y * numpixels.x + pixelCoord.x;
    uint rngState = pixelindex + Frame * 719393;

    float4 clipSpacePos = float4(uv * 2.0f - 1.0f, 0.0f, 1.0f);

    float4 viewSpacePos = mul(clipSpacePos, InverseProjection);
    viewSpacePos /= viewSpacePos.w;

    Ray ray = (Ray) 0;
    ray.Origin = CameraPosition;
    ray.Dir = normalize(mul(viewSpacePos.xyz, InverseView).xyz);
    
    float3 totalIncomingLight = 0;
    
    for (int rayIndex = 0; rayIndex < NumRaysPerPixel; rayIndex++)
    {
        totalIncomingLight += Trace(ray, rngState);
    }

    float3 pixelCol = totalIncomingLight / NumRaysPerPixel; 
    return float4(pixelCol, 1);
}


float4 ScreenPS(VertexShaderOutput input) : COLOR0
{
    float4 oldRender = tex2D(oldTextureSampler, input.TextureCoordinates);
    float4 newRender = tex2D(textureSampler, input.TextureCoordinates);
    
    float weight = 1.0 / (NumRenderedFrames + 1);
    float4 accumulatedAverage = oldRender * (1 - weight) + newRender * weight;
    
    return accumulatedAverage;
}
 
technique RayTracing
{
    pass Pass0
    {
        VertexShader = compile vs_5_0 MainVS();
        PixelShader = compile ps_5_0 RayTracingPS();
    }
}

technique Screen
{
    pass Pass0
    {
        VertexShader = compile vs_5_0 MainVS();
        PixelShader = compile ps_5_0 ScreenPS();
    }
}
