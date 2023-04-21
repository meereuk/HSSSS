using UnityEngine;
using System.Collections;
using UnityEngine.Rendering;

//[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class TemporalProjector : MonoBehaviour
{
    public Camera mCamera;
    public Shader mShader;
    private Material mMaterial;
    private CommandBuffer mBuffer;
    private RenderTexture mTexture;

    private Matrix4x4 WorldToViewMatrix;
    private Matrix4x4 ViewToWorldMatrix;
    private Matrix4x4 ViewToClipMatrix;
    private Matrix4x4 ClipToViewMatrix;
    private Matrix4x4 PrevWorldToViewMatrix;
    private Matrix4x4 PrevViewToWorldMatrix;
    private Matrix4x4 PrevViewToClipMatrix;
    private Matrix4x4 PrevClipToViewMatrix;

    public void OnEnable()
    {
        this.mCamera = GetComponent<Camera>();

        this.mMaterial = new Material(Shader.Find("Hidden/HSSSS/TemporalBlend"));
        this.mTexture = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.RGFloat, RenderTextureReadWrite.Linear);
        this.mTexture.Create();
    }
    
    public void OnDisable()
    {
        this.RemoveCommandBuffer();
        this.mCamera = null;
    }

    public void Start()
    {
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
        this.mMaterial.SetMatrix("_ViewToClipMatrix", this.ViewToClipMatrix);
        this.mMaterial.SetMatrix("_ClipToViewMatrix", this.ClipToViewMatrix);

        this.mMaterial.SetMatrix("_PrevWorldToViewMatrix", this.PrevWorldToViewMatrix);
        this.mMaterial.SetMatrix("_PrevViewToWorldMatrix", this.PrevViewToWorldMatrix);
        this.mMaterial.SetMatrix("_PrevViewToClipMatrix", this.PrevViewToClipMatrix);
        this.mMaterial.SetMatrix("_PrevClipToViewMatrix", this.PrevClipToViewMatrix);

        this.mMaterial.SetTexture("_CameraDepthHistory", this.mTexture);
    }

    private void SetupCommandBuffer()
    {
        this.mBuffer = new CommandBuffer() { name = "HSSSS.TemporalReprojector" };
        RenderTargetIdentifier zHist = new RenderTargetIdentifier(this.mTexture);
        int flipRT = Shader.PropertyToID("_SSSSSSSSSSTemporalFlipTexture");
        this.mBuffer.GetTemporaryRT(flipRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.RGFloat, RenderTextureReadWrite.Linear);
        this.mBuffer.Blit(BuiltinRenderTextureType.CurrentActive, flipRT, this.mMaterial, 0);
        this.mBuffer.Blit(flipRT, zHist);
        this.mBuffer.Blit(zHist, BuiltinRenderTextureType.CameraTarget);
        this.mCamera.AddCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, this.mBuffer);
    }

    private void RemoveCommandBuffer()
    {
        this.mCamera.RemoveCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, this.mBuffer);
        this.mBuffer = null;
    }

    private void ClearTemporalTexture()
    {
        /*
        RenderTexture rt = RenderTexture.active;
        RenderTexture.active = this.aoRenderTexture;
        GL.Clear(true, true, Color.clear);
        RenderTexture.active = this.giRenderTexture;
        GL.Clear(true, true, Color.clear);
        RenderTexture.active = rt;
        */
    }
}
