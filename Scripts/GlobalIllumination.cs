using UnityEngine;
using System.Collections;
using UnityEngine.Rendering;

[RequireComponent(typeof(Camera))]
public class GlobalIllumination : MonoBehaviour
{
    public Camera mCamera;
    private Material mMaterial;

    public float SSGIIntensity;
    public float SSGIMixFactor;
    public float SSGIRayLength;
    public float SSGIMeanDepth;
    public float SSGIFadeDepth;
    public int   SSGIStepPower;

    public Texture3D BlueNoise;

    private Matrix4x4 WorldToViewMatrix;
    private Matrix4x4 ViewToWorldMatrix;
    private Matrix4x4 ViewToClipMatrix;
    private Matrix4x4 ClipToViewMatrix;
    private Matrix4x4 PrevWorldToViewMatrix;
    private Matrix4x4 PrevViewToWorldMatrix;
    private Matrix4x4 PrevViewToClipMatrix;
    private Matrix4x4 PrevClipToViewMatrix;
    
    private CommandBuffer mBuffer;

    public struct HistoryBuffer
    {
        public RenderTexture diffuse;
        public RenderTexture specular;
        public RenderTexture normal;
        public RenderTexture depth;
    };

    private HistoryBuffer history;

    private static Mesh quad = null;

    private Mesh triangle;

    public void OnEnable()
    {
        this.mCamera = GetComponent<Camera>();
        this.mMaterial = new Material(Shader.Find("Hidden/HSSSS/GlobalIllumination"));
        this.mMaterial.SetTexture("_BlueNoise", this.BlueNoise);

        quad = new Mesh();

        quad.vertices = new Vector3[] {
            new Vector3(-1.0f, -1.0f, 0.0f),
            new Vector3(-1.0f,  3.0f, 0.0f),
            new Vector3( 3.0f, -1.0f, 0.0f),
        };

        quad.triangles = new int[] { 0, 1, 2 };
    }
    
    public void OnDisable()
    {
        this.RemoveCommandBuffer();
        this.RemoveHistoryBuffer();
        this.mCamera = null;
    }

    public void Start()
    {
        this.SetUpHistoryBuffer();
        this.SetupCommandBuffer();
    }

    public void OnPreRender()
    {
        this.PrevWorldToViewMatrix = this.WorldToViewMatrix;
        this.PrevViewToWorldMatrix = this.ViewToWorldMatrix;

        this.PrevViewToClipMatrix = this.ViewToClipMatrix;
        this.PrevClipToViewMatrix = this.ClipToViewMatrix;

        this.WorldToViewMatrix = mCamera.worldToCameraMatrix;
        this.ViewToWorldMatrix = this.WorldToViewMatrix.inverse;
        this.ViewToClipMatrix = mCamera.projectionMatrix;
        this.ClipToViewMatrix = this.ViewToClipMatrix.inverse;

        this.mMaterial.SetMatrix("_WorldToViewMatrix", this.WorldToViewMatrix);
        this.mMaterial.SetMatrix("_ViewToWorldMatrix", this.ViewToWorldMatrix);
        this.mMaterial.SetMatrix("_PrevWorldToViewMatrix", this.PrevWorldToViewMatrix);
        this.mMaterial.SetMatrix("_PrevViewToWorldMatrix", this.PrevViewToWorldMatrix);

        this.mMaterial.SetMatrix("_ViewToClipMatrix", this.ViewToClipMatrix);
        this.mMaterial.SetMatrix("_ClipToViewMatrix", this.ClipToViewMatrix);
        this.mMaterial.SetMatrix("_PrevViewToClipMatrix", this.PrevViewToClipMatrix);
        this.mMaterial.SetMatrix("_PrevClipToViewMatrix", this.PrevClipToViewMatrix);

        this.mMaterial.SetFloat("_SSGIFadeDepth", SSGIFadeDepth);
        this.mMaterial.SetFloat("_SSGIMeanDepth", SSGIMeanDepth);
        this.mMaterial.SetFloat("_SSGIMixFactor", SSGIMixFactor);
        this.mMaterial.SetFloat("_SSGIRayLength", SSGIRayLength);
        this.mMaterial.SetFloat("_SSGIIntensity", SSGIIntensity);
        this.mMaterial.SetInt(  "_SSGIStepPower", SSGIStepPower);

        this.mMaterial.SetInt(  "_FrameCount", Time.frameCount);
        this.mMaterial.SetTexture("_BlueNoise", this.BlueNoise);
    }

    private void OnPostRender()
    {
        /*
        this.history.diffuse.Release();
        this.history.specular.Release();
        this.history.normal.Release();
        this.history.depth.Release();
        */
    }

    private void SetupCommandBuffer()
    {
        RenderTargetIdentifier[] hist =
        {
            new RenderTargetIdentifier(this.history.diffuse),
            new RenderTargetIdentifier(this.history.specular),
            new RenderTargetIdentifier(this.history.normal),
            new RenderTargetIdentifier(this.history.depth)
        };

        int[] irad = new int[]{
            Shader.PropertyToID("_HierachicalIrradianceBuffer0"),
            Shader.PropertyToID("_HierachicalIrradianceBuffer1"),
            Shader.PropertyToID("_HierachicalIrradianceBuffer2"),
            Shader.PropertyToID("_HierachicalIrradianceBuffer3")
        };

        int[] flip = new int[]{
            Shader.PropertyToID("_SSGIFlipDiffuseBuffer"),
            Shader.PropertyToID("_SSGIFlipSpecularBuffer")
        };

        int[] flop = new int[]{
            Shader.PropertyToID("_SSGIFlopDiffuseBuffer"),
            Shader.PropertyToID("_SSGIFlopSpecularBuffer")
        };

        RenderTargetIdentifier[] iradMRT = { irad[0], irad[1], irad[2], irad[3] };
        RenderTargetIdentifier[] flipMRT = { flip[0], flip[1]};
        RenderTargetIdentifier[] flopMRT = { flop[0], flop[1]};

        this.mBuffer = new CommandBuffer() { name = "HSSSS.SSGI" };

        this.mBuffer.GetTemporaryRT(irad[0], -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.mBuffer.GetTemporaryRT(irad[1], this.mCamera.pixelWidth / 2, this.mCamera.pixelHeight / 2, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.mBuffer.GetTemporaryRT(irad[2], this.mCamera.pixelWidth / 4, this.mCamera.pixelHeight / 4, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.mBuffer.GetTemporaryRT(irad[3], this.mCamera.pixelWidth / 8, this.mCamera.pixelHeight / 8, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        
        this.mBuffer.GetTemporaryRT(flip[0], -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.mBuffer.GetTemporaryRT(flip[1], -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

        this.mBuffer.GetTemporaryRT(flop[0], -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.mBuffer.GetTemporaryRT(flop[1], -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

        this.mBuffer.Blit(BuiltinRenderTextureType.CameraTarget, irad[0], this.mMaterial, 0);
        this.mBuffer.Blit(irad[0], irad[1], this.mMaterial, 1);
        this.mBuffer.Blit(irad[1], irad[2], this.mMaterial, 1);
        this.mBuffer.Blit(irad[2], irad[3], this.mMaterial, 1);

        // main pass
        this.mBuffer.SetRenderTarget(flipMRT, BuiltinRenderTextureType.CameraTarget);
        this.mBuffer.DrawMesh(quad, Matrix4x4.identity, this.mMaterial, 0, 5);

        // temporal filter
        this.mBuffer.SetRenderTarget(flopMRT, BuiltinRenderTextureType.CameraTarget);
        this.mBuffer.DrawMesh(quad, Matrix4x4.identity, this.mMaterial, 0, 6);

        // spatio filter
        this.mBuffer.SetRenderTarget(flipMRT, BuiltinRenderTextureType.CameraTarget);
        this.mBuffer.DrawMesh(quad, Matrix4x4.identity, this.mMaterial, 0, 7);
        this.mBuffer.SetRenderTarget(flopMRT, BuiltinRenderTextureType.CameraTarget);
        this.mBuffer.DrawMesh(quad, Matrix4x4.identity, this.mMaterial, 0, 8);
        this.mBuffer.SetRenderTarget(flipMRT, BuiltinRenderTextureType.CameraTarget);
        this.mBuffer.DrawMesh(quad, Matrix4x4.identity, this.mMaterial, 0, 9);
        this.mBuffer.SetRenderTarget(flopMRT, BuiltinRenderTextureType.CameraTarget);
        this.mBuffer.DrawMesh(quad, Matrix4x4.identity, this.mMaterial, 0, 12);

        // store normal and history
        this.mBuffer.SetRenderTarget(hist, BuiltinRenderTextureType.CameraTarget);
        this.mBuffer.DrawMesh(quad, Matrix4x4.identity, this.mMaterial, 0, 10);

        // debug
        this.mBuffer.Blit(flip[0], flip[1], this.mMaterial, 11);

        this.mBuffer.Blit(flip[1], BuiltinRenderTextureType.CameraTarget);

        this.mBuffer.ReleaseTemporaryRT(irad[0]);
        this.mBuffer.ReleaseTemporaryRT(irad[1]);
        this.mBuffer.ReleaseTemporaryRT(irad[2]);
        this.mBuffer.ReleaseTemporaryRT(irad[3]);

        this.mBuffer.ReleaseTemporaryRT(flip[0]);
        this.mBuffer.ReleaseTemporaryRT(flip[1]);

        this.mBuffer.ReleaseTemporaryRT(flop[0]);
        this.mBuffer.ReleaseTemporaryRT(flop[1]);

        this.mCamera.AddCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, this.mBuffer);
    }

    private void RemoveCommandBuffer()
    {
        this.mCamera.RemoveCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, this.mBuffer);
        this.mBuffer = null;
    }

    private void SetUpHistoryBuffer()
    {
        this.history.diffuse = new RenderTexture(this.mCamera.pixelWidth, this.mCamera.pixelHeight, 0, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.history.diffuse.SetGlobalShaderProperty("_SSGITemporalDiffuseBuffer");
        this.history.diffuse.Create();

        this.history.specular = new RenderTexture(this.mCamera.pixelWidth, this.mCamera.pixelHeight, 0, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.history.specular.SetGlobalShaderProperty("_SSGITemporalSpecularBuffer");
        this.history.specular.Create();

        this.history.normal = new RenderTexture(this.mCamera.pixelWidth, this.mCamera.pixelHeight, 0, RenderTextureFormat.ARGB2101010, RenderTextureReadWrite.Linear);
        this.history.normal.SetGlobalShaderProperty("_CameraNormalHistory");
        this.history.normal.Create();

        this.history.depth = new RenderTexture(this.mCamera.pixelWidth, this.mCamera.pixelHeight, 0, RenderTextureFormat.RHalf, RenderTextureReadWrite.Linear);
        this.history.depth.SetGlobalShaderProperty("_CameraDepthHistory");
        this.history.depth.Create();

        RenderTexture rt = RenderTexture.active;
        RenderTexture.active = this.history.diffuse;
        GL.Clear(true, true, Color.black);
        RenderTexture.active = this.history.specular;
        GL.Clear(true, true, Color.black);
        RenderTexture.active = rt;
    }

    private void RemoveHistoryBuffer()
    {
        if (this.history.diffuse != null)
        {
            this.history.diffuse.Release();
            this.history.diffuse = null;
        }

        if (this.history.specular != null)
        {
            this.history.specular.Release();
            this.history.specular = null;
        }

        if (this.history.normal != null)
        {
            this.history.normal.Release();
            this.history.normal = null;
        }

        if (this.history.depth != null)
        {
            this.history.depth.Release();
            this.history.depth = null;
        }
    }
}
