using UnityEngine;
using System.Collections;
using UnityEngine.Rendering;

//[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class ScreenSpaceRaytracing : MonoBehaviour
{
    public Camera mCamera;
    public Shader mShader;

    public Texture2D CheckerBoard;

    private Material mMaterial;

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

    private RenderTexture giRenderTexture;
    private RenderTexture aoRenderTexture;

    public void OnEnable()
    {
        this.mCamera = GetComponent<Camera>();
        this.mShader = Shader.Find("Hidden/HSSSS/AmbientOcclusion");
        this.mMaterial = new Material(this.mShader);
        this.mMaterial.SetTexture("_ShadowJitterTexture", this.CheckerBoard);

        this.giRenderTexture = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.aoRenderTexture = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.RHalf, RenderTextureReadWrite.Linear);

        giRenderTexture.Create();
        aoRenderTexture.Create();
    }
    
    public void OnDisable()
    {
        this.RemoveCommandBuffer();
        this.mCamera = null;
        this.mShader = null;
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
        this.mMaterial.SetMatrix("_PrevWorldToViewMatrix", this.PrevWorldToViewMatrix);
        this.mMaterial.SetMatrix("_PrevViewToWorldMatrix", this.PrevViewToWorldMatrix);

        this.mMaterial.SetMatrix("_ViewToClipMatrix", this.ViewToClipMatrix);
        this.mMaterial.SetMatrix("_ClipToViewMatrix", this.ClipToViewMatrix);
        this.mMaterial.SetMatrix("_PrevViewToClipMatrix", this.PrevViewToClipMatrix);
        this.mMaterial.SetMatrix("_PrevClipToViewMatrix", this.PrevClipToViewMatrix);

        this.mMaterial.SetFloat("_SSAOFadeDepth", 100.0f);
        this.mMaterial.SetFloat("_SSAOMeanDepth", 0.2f);
        this.mMaterial.SetFloat("_SSAOBiasAngle", 0.0f);
        this.mMaterial.SetFloat("_SSAOMixFactor", 0.0f);
        this.mMaterial.SetFloat("_SSAORayLength", 4.0f);
        this.mMaterial.SetFloat("_SSAOIntensity", 1.0f); 
        this.mMaterial.SetInt("_SSAOStepPower", 1);

        this.mMaterial.SetTexture("_SSGITemporalAOBuffer", this.aoRenderTexture);
    }

    private void SetupCommandBuffer()
    {
        this.ClearTemporalTexture();

        int flipRT = Shader.PropertyToID("_SSAOTemporalFlipTexture");
        int flopRT = Shader.PropertyToID("_SSAOTemporalFlopTexture");
        RenderTargetIdentifier tempAO = new RenderTargetIdentifier(this.aoRenderTexture);

        this.aoBuffer = new CommandBuffer() { name = "HSSSS.SSAO" };
        this.aoBuffer.GetTemporaryRT(flipRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.aoBuffer.GetTemporaryRT(flopRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

        this.aoBuffer.Blit(BuiltinRenderTextureType.CurrentActive, flipRT, this.mMaterial, 7);
        // spatio filtering
        /*
        this.aoBuffer.Blit(flipRT, flopRT, this.mMaterial, 10);
        this.aoBuffer.Blit(flopRT, flipRT, this.mMaterial, 11);
        this.aoBuffer.Blit(flipRT, flopRT, this.mMaterial, 10);
        this.aoBuffer.Blit(flopRT, flipRT, this.mMaterial, 11);
        */
        // temporal filtering
        this.aoBuffer.Blit(flipRT, tempAO);
        // apply
        this.aoBuffer.Blit(tempAO, flopRT, this.mMaterial, 8);
        this.aoBuffer.Blit(flopRT, BuiltinRenderTextureType.GBuffer0);

        this.aoBuffer.Blit(tempAO, flopRT, this.mMaterial, 9);
        this.aoBuffer.Blit(flopRT, BuiltinRenderTextureType.CameraTarget);
        // apply

        this.aoBuffer.ReleaseTemporaryRT(flipRT);
        this.aoBuffer.ReleaseTemporaryRT(flopRT);

        this.mCamera.AddCommandBuffer(CameraEvent.BeforeReflections, this.aoBuffer);

        this.giBuffer = new CommandBuffer() { name = "HSSSS.SSGI" };

        int fuckRT = Shader.PropertyToID("_IdOnTgIvEaFuCk");

        this.giBuffer.GetTemporaryRT(fuckRT, -1, -1, 24, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

        this.giBuffer.Blit(BuiltinRenderTextureType.CurrentActive, fuckRT, this.mMaterial, 12);
        this.giBuffer.Blit(fuckRT, BuiltinRenderTextureType.CameraTarget);

        this.mCamera.AddCommandBuffer(CameraEvent.AfterEverything, this.giBuffer);
    }

    private void RemoveCommandBuffer()
    {
        this.mCamera.RemoveCommandBuffer(CameraEvent.BeforeReflections, this.aoBuffer);
        this.mCamera.RemoveCommandBuffer(CameraEvent.AfterEverything, this.giBuffer);
        this.aoBuffer = null;
        this.giBuffer = null;
    }

    private void ClearTemporalTexture()
    {
        RenderTexture rt = RenderTexture.active;
        RenderTexture.active = this.aoRenderTexture;
        GL.Clear(true, true, Color.clear);
        RenderTexture.active = this.giRenderTexture;
        GL.Clear(true, true, Color.clear);
        RenderTexture.active = rt;
    }
}
