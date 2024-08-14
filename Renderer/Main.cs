using System;
using ImGuiNET;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using MonoGame.ImGuiNet;
using Renderer.Cameras;
using Renderer.Geometries;
using SharpDX.Direct3D9;
using Effect = Microsoft.Xna.Framework.Graphics.Effect;

namespace Renderer
{
    public class Main : Game
    {
        public const string ContentFolder3D = "Models/";
        public const string ContentFolderEffects = "Effects/";
        public const string ContentFolderTextures = "Textures/";
        public static ImGuiRenderer GuiRenderer;

        private GraphicsDeviceManager _graphicsDeviceManager;

        private FreeCamera _freeCamera;
        private FullScreenQuad _fullScreenQuad;
        private RenderTarget2D _currentFrame;
        private RenderTarget2D _previousFrame;
        private RenderTarget2D _accumulatedFrame;
        private Effect _rayTracingEffect;
        private Effect _denoiseEffect;
        private SpriteBatch _spriteBatch;

        private int _numRenderedFrames;
        private int _maxBounceCount = 30;
        private int _numRaysPerPixel = 10;

        public Main()
        {
            _graphicsDeviceManager = new GraphicsDeviceManager(this);
            Content.RootDirectory = "Content";
            IsMouseVisible = true;
            _graphicsDeviceManager.GraphicsProfile = GraphicsProfile.HiDef;
            Window.AllowUserResizing = true;
        }

        protected override void Initialize()
        {
            _graphicsDeviceManager.PreferredBackBufferWidth = GraphicsAdapter.DefaultAdapter.CurrentDisplayMode.Width - 100;
            _graphicsDeviceManager.PreferredBackBufferHeight = GraphicsAdapter.DefaultAdapter.CurrentDisplayMode.Height - 100;
            _graphicsDeviceManager.ApplyChanges();

            _freeCamera = new FreeCamera(GraphicsDevice.Viewport.AspectRatio, new Vector3(0f, 100f, 500f));
            _fullScreenQuad = new FullScreenQuad(GraphicsDevice);
            
            _currentFrame = new RenderTarget2D(GraphicsDevice, GraphicsDevice.Viewport.Width, 
                GraphicsDevice.Viewport.Height, false, SurfaceFormat.Color, 
                DepthFormat.Depth24Stencil8, 0, RenderTargetUsage.DiscardContents);
            
            _previousFrame = new RenderTarget2D(GraphicsDevice, GraphicsDevice.Viewport.Width, 
                GraphicsDevice.Viewport.Height, false, SurfaceFormat.Color, 
                DepthFormat.Depth24Stencil8, 0, RenderTargetUsage.DiscardContents);
            
            _accumulatedFrame = new RenderTarget2D(GraphicsDevice, GraphicsDevice.Viewport.Width, 
                GraphicsDevice.Viewport.Height, false, SurfaceFormat.Color, 
                DepthFormat.Depth24Stencil8, 0, RenderTargetUsage.DiscardContents);

            GuiRenderer = new ImGuiRenderer(this);

            base.Initialize();
        }

        protected override void LoadContent()
        {
            _spriteBatch = new SpriteBatch(GraphicsDevice);
            
            _rayTracingEffect = Content.Load<Effect>(ContentFolderEffects + "RayTracing");
            _denoiseEffect = Content.Load<Effect>(ContentFolderEffects + "Denoise");
            
            GuiRenderer.RebuildFontAtlas();
            
            base.LoadContent();
        }

        protected override void Update(GameTime gameTime)
        {
            var keyboardState = Keyboard.GetState();
            
            _freeCamera.Update(gameTime);
            Console.WriteLine("Position: " + _freeCamera.Position);
            Console.WriteLine("Direction: " + _freeCamera.FrontDirection);
            
            if (keyboardState.IsKeyDown(Keys.Escape))
            {
                Exit();
            }
            base.Update(gameTime);
        }
        
        protected override void Draw(GameTime gameTime)
        {
            // Render scene
            DrawRayTracedScene();
            
            // Accumulate based on rendered frames
            AccumulateFrames();

            // Copy result to _previousFrame
            CopyRenderTarget(_accumulatedFrame, _previousFrame);
            
            // Draw to screen
            DrawToScreen();

            _numRenderedFrames = !_freeCamera.HasChanged() ? _numRenderedFrames + 1 : 1;
            
            DrawGui(gameTime);
            base.Draw(gameTime);
        }

        private void DrawToScreen()
        {
            GraphicsDevice.SetRenderTarget(null);
            GraphicsDevice.Clear(Color.Black);
            
            _spriteBatch.Begin();
            _spriteBatch.Draw(_accumulatedFrame, GraphicsDevice.Viewport.Bounds, Color.White);
            _spriteBatch.End();
        }

        private void CopyRenderTarget(RenderTarget2D source, RenderTarget2D destination)
        {
            GraphicsDevice.SetRenderTarget(destination);
            GraphicsDevice.Clear(Color.Black);

            _spriteBatch.Begin();
            _spriteBatch.Draw(source, GraphicsDevice.Viewport.Bounds, Color.White);
            _spriteBatch.End();
        }
        
        private void AccumulateFrames()
        {
            GraphicsDevice.SetRenderTarget(_accumulatedFrame);
            GraphicsDevice.Clear(Color.Black);
            
            _denoiseEffect.CurrentTechnique = _denoiseEffect.Techniques["Denoise"];
            _denoiseEffect.Parameters["CurrentFrame"].SetValue(_currentFrame);
            _denoiseEffect.Parameters["PreviousFrame"].SetValue(_previousFrame);
            _denoiseEffect.Parameters["NumRenderedFrames"].SetValue(_numRenderedFrames);
            
            _fullScreenQuad.Draw(_denoiseEffect);
        }

        private void DrawRayTracedScene()
        {
            GraphicsDevice.SetRenderTarget(_currentFrame);
            GraphicsDevice.Clear(Color.Black);
            
            _rayTracingEffect.CurrentTechnique = _rayTracingEffect.Techniques["RayTracing"];
            _rayTracingEffect.Parameters["MaxBounceCount"].SetValue(_maxBounceCount);
            _rayTracingEffect.Parameters["NumRaysPerPixel"].SetValue(_numRaysPerPixel);
            _rayTracingEffect.Parameters["Frame"].SetValue(_numRenderedFrames);
            _rayTracingEffect.Parameters["ViewportWidth"].SetValue(GraphicsDevice.Viewport.Width);
            _rayTracingEffect.Parameters["ViewportHeight"].SetValue(GraphicsDevice.Viewport.Height);
            _rayTracingEffect.Parameters["InverseView"].SetValue(Matrix.Invert(_freeCamera.View));
            _rayTracingEffect.Parameters["InverseProjection"].SetValue(Matrix.Invert(_freeCamera.Projection));
            _rayTracingEffect.Parameters["CameraPosition"].SetValue(_freeCamera.Position);
            
            _fullScreenQuad.Draw(_rayTracingEffect);
        }
        
        private void DrawGui(GameTime gameTime)
        {
            GuiRenderer.BeginLayout(gameTime);

            ImGui.Begin("Settings", ImGuiWindowFlags.AlwaysAutoResize);
            
            ImGui.SetWindowSize(new System.Numerics.Vector2(400, 200));
            
            ImGui.Text($"FPS: {1.0 / gameTime.ElapsedGameTime.TotalSeconds:0.0}");
            ImGui.Text($"Framerate: {gameTime.ElapsedGameTime.TotalSeconds * 1000:0.0} ms");
            ImGui.Text($"Accumulated frames: {_numRenderedFrames}");
            
            ImGui.Separator();
            ImGui.Text("Ray Tracing Settings");
            ImGui.DragInt("Max Bounce Count", ref _maxBounceCount, 1, 1, 500);
            ImGui.DragInt("Numbers of Rays Per Pixel", ref _numRaysPerPixel, 1, 1, 300);
            
            ImGui.Separator();
            ImGui.Text("Camera Information");
            ImGui.Text($"Camera Front Direction: {_freeCamera.FrontDirection}");
            ImGui.Text($"Camera Position: {_freeCamera.Position}");
            
            ImGui.End();

            GuiRenderer.EndLayout();
        }
        
        protected override void UnloadContent()
        {
            _currentFrame.Dispose();
            _previousFrame.Dispose();
            _accumulatedFrame.Dispose();
            base.UnloadContent();
        }
    }
}