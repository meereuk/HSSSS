using UnityEngine;
using System.Collections;
using UnityEngine.Rendering;

//[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class AmbientOcclusion : MonoBehaviour
{
    public Camera mCamera;
    private Material mMaterial;

    public float SSAOIntensity;
    public float SSAOMixFactor;
    public float SSAORayLength;
    public float SSAOMeanDepth;
    public float SSAOFadeDepth;
    public int   SSAOStepPower;
    public int   SSAOBlockSize;
    public int   SSAONumStride; 

    private Matrix4x4 WorldToViewMatrix;
    private Matrix4x4 ViewToWorldMatrix;
    private Matrix4x4 ViewToClipMatrix;
    private Matrix4x4 ClipToViewMatrix;
    private Matrix4x4 PrevWorldToViewMatrix;
    private Matrix4x4 PrevViewToWorldMatrix;
    private Matrix4x4 PrevViewToClipMatrix;
    private Matrix4x4 PrevClipToViewMatrix;

    private CommandBuffer aoBuffer;
    private RenderTexture aoHistory;

    public void OnEnable()
    {
        this.mCamera = GetComponent<Camera>();
        this.mMaterial = new Material(Shader.Find("Hidden/HSSSS/AmbientOcclusion"));
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
        this.mMaterial.SetInt(  "_SSAONumStride", SSAONumStride);

        this.mMaterial.SetTexture("_SSGITemporalAOBuffer", this.aoHistory);
    }

    private void SetupCommandBuffer()
    {
        this.aoHistory = RenderTexture.GetTemporary(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

        RenderTargetIdentifier temp = new RenderTargetIdentifier(this.aoHistory);

        int depth = Shader.PropertyToID("_SSAOTemporalDepthTexture");
        int flip = Shader.PropertyToID("_SSAOTemporalFlipTexture");
        int flop = Shader.PropertyToID("_SSAOTemporalFlopTexture");

        this.aoBuffer = new CommandBuffer() { name = "HSSSS.SSAO" };

        this.aoBuffer.GetTemporaryRT(depth, Screen.width, Screen.height, 0, FilterMode.Bilinear, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
        this.aoBuffer.GetTemporaryRT(flip, Screen.width, Screen.height, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.aoBuffer.GetTemporaryRT(flop, Screen.width, Screen.height, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

        this.aoBuffer.Blit(temp, depth, this.mMaterial, 0);
        this.aoBuffer.Blit(depth, flip, this.mMaterial, 8);

        this.aoBuffer.Blit(flip, flop, this.mMaterial, 9);
        this.aoBuffer.Blit(flop, flip, this.mMaterial, 10);

        this.aoBuffer.Blit(flip, flop, this.mMaterial, 11);

        this.aoBuffer.Blit(flop, temp);

        this.aoBuffer.Blit(flop, flip, this.mMaterial, 15);
        this.aoBuffer.Blit(flip, BuiltinRenderTextureType.CameraTarget);

        this.mCamera.AddCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, this.aoBuffer);
    }

    private void RemoveCommandBuffer()
    {
        this.mCamera.RemoveCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, this.aoBuffer);
        this.aoBuffer = null;
    }
}
