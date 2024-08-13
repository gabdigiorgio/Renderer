using Microsoft.Xna.Framework;

namespace Renderer.Geometries;

public struct Sphere
{
    public Vector3 Position;
    public float Radius;
    public Vector3 Color;

    public Sphere(Vector3 position, float radius, Vector3 color)
    {
        Position = position;
        Radius = radius;
        Color = color;
    }

}