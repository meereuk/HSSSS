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
    public int   SSGIScreenDiv;

    public Texture3D BlueNoise;

    private Matrix4x4 WorldToViewMatrix;
    private Matrix4x4 ViewToWorldMatrix;
    private Matrix4x4 ViewToClipMatrix;
    private Matrix4x4 ClipToViewMatrix;
    private Matrix4x4 PrevWorldToViewMatrix;
    private Matrix4x4 PrevViewToWorldMatrix;
    private Matrix4x4 PrevViewToClipMatrix;
    private Matrix4x4 PrevClipToViewMatrix;

    private CommandBuffer aoBuffer;
    private CommandBuffer giBuffer;

    private RenderTexture giHistory;
    private RenderTexture zbHistory;

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
            //new Vector3( 1.0f, -1.0f, 0.0f)
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
        this.mMaterial.SetInt(  "_SSGIScreenDiv", SSGIScreenDiv);

        this.mMaterial.SetInt(  "_FrameCount", Time.frameCount);

        this.mMaterial.SetTexture("_SSGITemporalGIBuffer", this.giHistory);
        this.mMaterial.SetTexture("_CameraDepthHistory", this.zbHistory);
        this.mMaterial.SetTexture("_BlueNoise", this.BlueNoise);
    }

    private void SetupCommandBuffer()
    {
        RenderTargetIdentifier temp = new RenderTargetIdentifier(this.giHistory);
        RenderTargetIdentifier zbuf = new RenderTargetIdentifier(this.zbHistory);

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

        this.aoBuffer = new CommandBuffer() { name = "HSSSS.SSGI" };

        this.aoBuffer.GetTemporaryRT(irad[0], -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.aoBuffer.GetTemporaryRT(irad[1], this.mCamera.pixelWidth / 2, this.mCamera.pixelHeight / 2, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.aoBuffer.GetTemporaryRT(irad[2], this.mCamera.pixelWidth / 4, this.mCamera.pixelHeight / 4, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.aoBuffer.GetTemporaryRT(irad[3], this.mCamera.pixelWidth / 8, this.mCamera.pixelHeight / 8, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        
        this.aoBuffer.GetTemporaryRT(flip[0], -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.aoBuffer.GetTemporaryRT(flip[1], -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

        this.aoBuffer.GetTemporaryRT(flop[0], -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.aoBuffer.GetTemporaryRT(flop[1], -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

        this.aoBuffer.Blit(temp, irad[0], this.mMaterial, 0);
        this.aoBuffer.Blit(irad[0], irad[1]);
        this.aoBuffer.Blit(irad[1], irad[2]);
        this.aoBuffer.Blit(irad[2], irad[3]);

        this.aoBuffer.SetRenderTarget(flipMRT, BuiltinRenderTextureType.CameraTarget);
        this.aoBuffer.DrawMesh(quad, Matrix4x4.identity, this.mMaterial, 0, 4);

        // spatio filter
        /*
        this.aoBuffer.SetRenderTarget(flopMRT, BuiltinRenderTextureType.CameraTarget);
        this.aoBuffer.DrawMesh(quad, Matrix4x4.identity, this.mMaterial, 0, 6);
        this.aoBuffer.SetRenderTarget(flipMRT, BuiltinRenderTextureType.CameraTarget);
        this.aoBuffer.DrawMesh(quad, Matrix4x4.identity, this.mMaterial, 0, 7);
        this.aoBuffer.SetRenderTarget(flopMRT, BuiltinRenderTextureType.CameraTarget);
        this.aoBuffer.DrawMesh(quad, Matrix4x4.identity, this.mMaterial, 0, 8);
        this.aoBuffer.SetRenderTarget(flipMRT, BuiltinRenderTextureType.CameraTarget);
        this.aoBuffer.DrawMesh(quad, Matrix4x4.identity, this.mMaterial, 0, 9);
        */

        // temporal filter
        this.aoBuffer.Blit(null, flop[0], this.mMaterial, 5);
        // store
        this.aoBuffer.Blit(flop[0], temp);
        this.aoBuffer.Blit(temp, zbuf, this.mMaterial, 12);

        // collect pass
        this.aoBuffer.Blit(flop[0], flip[0], this.mMaterial, 11);
        this.aoBuffer.Blit(flip[0], BuiltinRenderTextureType.CameraTarget);

        this.aoBuffer.ReleaseTemporaryRT(irad[0]);
        this.aoBuffer.ReleaseTemporaryRT(irad[1]);
        this.aoBuffer.ReleaseTemporaryRT(irad[2]);
        this.aoBuffer.ReleaseTemporaryRT(irad[3]);

        this.aoBuffer.ReleaseTemporaryRT(flip[0]);
        this.aoBuffer.ReleaseTemporaryRT(flip[1]);

        this.aoBuffer.ReleaseTemporaryRT(flop[0]);
        this.aoBuffer.ReleaseTemporaryRT(flop[1]);

        this.mCamera.AddCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, this.aoBuffer);
    }

    private void RemoveCommandBuffer()
    {
        this.mCamera.RemoveCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, this.aoBuffer);
        this.aoBuffer = null;
    }

    private void SetUpHistoryBuffer()
    {
        this.giHistory = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.giHistory.filterMode = FilterMode.Bilinear;
        this.giHistory.Create();

        this.zbHistory = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
        this.zbHistory.Create();

        RenderTexture rt = RenderTexture.active;
        RenderTexture.active = this.giHistory;
        GL.Clear(true, true, Color.clear);
        RenderTexture.active = this.zbHistory;
        GL.Clear(true, true, Color.clear);
        RenderTexture.active = rt;
    }

    private void RemoveHistoryBuffer()
    {
        this.giHistory.Release();
        this.zbHistory.Release();
        this.giHistory = null;
        this.zbHistory = null;
    }
}
