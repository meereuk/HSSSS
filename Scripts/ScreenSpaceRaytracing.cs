using UnityEngine;
using System.Collections;
using UnityEngine.Rendering;

//[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class ScreenSpaceRaytracing : MonoBehaviour
{
    public Camera mCamera;
    public Shader mShader;

    private Material mMaterial;
    private Matrix4x4 WorldToViewMatrix;
    private Matrix4x4 ViewToWorldMatrix;
    private Matrix4x4 ViewToClipMatrix;
    private Matrix4x4 ClipToViewMatrix;
    private Matrix4x4 PrevWorldToViewMatrix;
    private Matrix4x4 PrevViewToWorldMatrix;
    private Matrix4x4 PrevViewToClipMatrix;
    private Matrix4x4 PrevClipToViewMatrix;




    private CommandBuffer mBuffer;

    private RenderTexture giBuffer;
    private RenderTexture aoBuffer;

    public void OnEnable()
    {
        this.mCamera = GetComponent<Camera>();
        this.mShader = Shader.Find("Hidden/HSSSS/ScreenSpacePathTracing");
        this.mMaterial = new Material(this.mShader);

        this.giBuffer = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.aoBuffer = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

        giBuffer.Create();
        aoBuffer.Create();
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

        this.mMaterial.SetFloat("_SSAODepthFade", 10.0f);
        this.mMaterial.SetFloat("_SSAODepthBias", 0.1f);
        this.mMaterial.SetFloat("_SSAOMixFactor", 0.5f);
        this.mMaterial.SetFloat("_SSAORayLength", 4.0f);
        this.mMaterial.SetFloat("_SSAOIndirectP", 1.0f);

        this.mMaterial.SetTexture("_SSGITemporalGIBuffer", this.giBuffer);
        this.mMaterial.SetTexture("_SSGITemporalAOBuffer", this.aoBuffer);

        Shader.SetGlobalTexture("_SSGITemporalAOBuffer", this.aoBuffer);
    }

    private void SetupCommandBuffer()
    {
        this.ClearTemporalTexture();

        int flipRT = Shader.PropertyToID("_SSAOTemporalFlipTexture");
        int flopRT = Shader.PropertyToID("_SSAOTemporalFlopTexture");
        RenderTargetIdentifier tempAO = new RenderTargetIdentifier(this.aoBuffer);
        RenderTargetIdentifier tempGI = new RenderTargetIdentifier(this.giBuffer);

        this.mBuffer = new CommandBuffer() { name = "HSSSS.SSAO" };
        this.mBuffer.GetTemporaryRT(flipRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.mBuffer.GetTemporaryRT(flopRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

        this.mBuffer.Blit(BuiltinRenderTextureType.CurrentActive, flipRT, this.mMaterial, 2);
        // temporal filter
        this.mBuffer.Blit(flipRT, flopRT, this.mMaterial, 4);
        this.mBuffer.Blit(flopRT, tempAO);
        this.mBuffer.Blit(flopRT, flipRT, this.mMaterial, 6);
        this.mBuffer.Blit(flipRT, BuiltinRenderTextureType.CameraTarget);
        // apply
        /*
        this.mBuffer.Blit(flopRT, flipRT, this.mMaterial, 2);
        this.mBuffer.Blit(flipRT, BuiltinRenderTextureType.GBuffer0);
        this.mBuffer.Blit(flopRT, flipRT, this.mMaterial, 3);
        this.mBuffer.Blit(flipRT, BuiltinRenderTextureType.CameraTarget);
        */

        this.mBuffer.ReleaseTemporaryRT(flipRT);
        this.mBuffer.ReleaseTemporaryRT(flopRT);

        this.mCamera.AddCommandBuffer(CameraEvent.BeforeImageEffects, this.mBuffer);
    }

    private void RemoveCommandBuffer()
    {
        this.mCamera.RemoveCommandBuffer(CameraEvent.BeforeImageEffects, this.mBuffer);
        this.mBuffer = null;
    }

    private void ClearTemporalTexture()
    {
        RenderTexture rt = RenderTexture.active;
        RenderTexture.active = this.aoBuffer;
        GL.Clear(true, true, Color.clear);
        RenderTexture.active = this.giBuffer;
        GL.Clear(true, true, Color.clear);
        RenderTexture.active = rt;
    }
}
