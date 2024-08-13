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

float4 MainPS(VertexShaderOutput input) : COLOR0
{
    float4 oldRender = tex2D(oldTextureSampler, input.TextureCoordinates);
    float4 newRender = tex2D(textureSampler, input.TextureCoordinates);
    
    float weight = 1.0 / (NumRenderedFrames + 1);
    float4 accumulatedAverage = oldRender * (1 - weight) + newRender * weight;
    
    return accumulatedAverage;
}
 
technique Denoise
{
    pass Pass0
    {
        VertexShader = compile vs_5_0 MainVS();
        PixelShader = compile ps_5_0 MainPS();
    }
}
