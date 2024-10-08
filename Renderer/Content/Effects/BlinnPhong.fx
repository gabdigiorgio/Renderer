﻿// Matrices
float4x4 World;
float4x4 View;
float4x4 Projection;
float4x4 InverseTransposeWorld;
 
// Light related
float3 Color;

float3 LightPosition;
float3 EyePosition;

float3 AmbientColor;
float KAmbient;
 
float3 DiffuseColor;
float KDiffuse;

float3 SpecularColor;
float KSpecular;
float Shininess;
 
struct VertexShaderInput
{
    float4 Position : POSITION0;
    float4 Normal : NORMAL;
};
 
struct VertexShaderOutput
{
    float4 Position : POSITION0;
    float3 WorldPosition : TEXCOORD0;
    float3 Normal : TEXCOORD1;
};
 
VertexShaderOutput MainVS(VertexShaderInput input)
{
    VertexShaderOutput output = (VertexShaderOutput) 0;
 
    float4 worldPosition = mul(input.Position, World);
    float4 viewPosition = mul(worldPosition, View);
    output.Position = mul(viewPosition, Projection);
    output.WorldPosition = worldPosition;
    output.Normal = mul(input.Normal, InverseTransposeWorld);
 
    return output;
}
 
float4 MainPS(VertexShaderOutput input) : COLOR0
{
    float3 lightDirection = normalize(LightPosition - input.WorldPosition);
    float3 viewDirection = normalize(EyePosition - input.WorldPosition);
    float3 halfVector = normalize(lightDirection + viewDirection); 
    
    float3 ambientLight = KAmbient * AmbientColor;
    
    float NdotL = saturate(dot(input.Normal, lightDirection));
    float3 diffuseLight = KDiffuse * DiffuseColor * NdotL;
    
    float NdotH = saturate(dot(input.Normal, halfVector));
    float3 specularLight = sign(NdotL) * KSpecular * SpecularColor * pow(NdotH, Shininess);

    float4 finalColor = float4((ambientLight + diffuseLight) * Color + specularLight, 1.0);
    
    return finalColor;
}

 
technique BasicColorDrawing
{
    pass Pass0
    {
        VertexShader = compile vs_5_0 MainVS();
        PixelShader = compile ps_5_0 MainPS();
    }
}