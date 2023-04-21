using UnityEngine;
using System.Collections;
using UnityEngine.Rendering;

//[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class ScreenSpaceRaytracing : MonoBehaviour
{
    public Camera mCamera;
    public Shader mShader;

    public float SSAOIntensity;
    public float SSAOMixFactor;
    public float SSAORayLength;
    public float SSAOMeanDepth;
    public float SSAOFadeDepth;
    public int   SSAOStepPower;
    public int   SSAOBlockSize;

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
    private RenderTexture aoRenderTexture;
    private RenderTexture zBufferHistory;

    public void OnEnable()
    {
        this.mCamera = GetComponent<Camera>();
        this.mShader = Shader.Find("Hidden/HSSSS/AmbientOcclusion");
        this.mMaterial = new Material(this.mShader);
        this.aoRenderTexture = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.zBufferHistory = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
        this.aoRenderTexture.Create();
        this.zBufferHistory.Create();
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

        this.mMaterial.SetFloat("_SSAOFadeDepth", SSAOFadeDepth);
        this.mMaterial.SetFloat("_SSAOMeanDepth", SSAOMeanDepth);
        this.mMaterial.SetFloat("_SSAOMixFactor", SSAOMixFactor);
        this.mMaterial.SetFloat("_SSAORayLength", SSAORayLength);
        this.mMaterial.SetFloat("_SSAOIntensity", SSAOIntensity);
        this.mMaterial.SetInt(  "_SSAOStepPower", SSAOStepPower);
        this.mMaterial.SetInt(  "_SSAOBlockSize", SSAOBlockSize);

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

        // ao calculation
        this.aoBuffer.Blit(BuiltinRenderTextureType.CurrentActive, flipRT, this.mMaterial, 7);
        // temporal filter
        this.aoBuffer.Blit(flipRT, flopRT, this.mMaterial, 9);
        this.aoBuffer.Blit(flopRT, flipRT, this.mMaterial, 10);
        //
        this.aoBuffer.Blit(flipRT, tempAO);
        // to gbuffer 3
        this.aoBuffer.Blit(BuiltinRenderTextureType.CameraTarget, flipRT, this.mMaterial, 12);
        this.aoBuffer.Blit(flipRT, BuiltinRenderTextureType.CameraTarget);
        // to reflections
        this.aoBuffer.Blit(BuiltinRenderTextureType.Reflections, flopRT, this.mMaterial, 13);
        this.aoBuffer.Blit(flopRT, BuiltinRenderTextureType.Reflections);
        //
        this.aoBuffer.Blit(tempAO, flopRT, this.mMaterial, 14);
        this.aoBuffer.Blit(flopRT, BuiltinRenderTextureType.CameraTarget);
        this.aoBuffer.ReleaseTemporaryRT(flipRT);
        this.aoBuffer.ReleaseTemporaryRT(flopRT);

        //this.mCamera.AddCommandBuffer(CameraEvent.AfterReflections, this.aoBuffer);
        this.mCamera.AddCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, this.aoBuffer);
    }

    private void RemoveCommandBuffer()
    {
        //this.mCamera.RemoveCommandBuffer(CameraEvent.AfterReflections, this.aoBuffer);
        this.mCamera.RemoveCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, this.aoBuffer);
        this.aoBuffer = null;
        this.zBufferHistory = null;
    }

    private void ClearTemporalTexture()
    {
        RenderTexture rt = RenderTexture.active;
        RenderTexture.active = this.aoRenderTexture;
        GL.Clear(true, true, Color.clear);
        RenderTexture.active = this.zBufferHistory;
        GL.Clear(true, true, Color.clear);
        RenderTexture.active = rt;
    }
}
