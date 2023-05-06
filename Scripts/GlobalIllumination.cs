using UnityEngine;
using System.Collections;
using UnityEngine.Rendering;

//[ExecuteInEditMode]
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

    public void OnEnable()
    {
        this.mCamera = GetComponent<Camera>();
        this.mMaterial = new Material(Shader.Find("Hidden/HSSSS/GlobalIllumination"));
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

        this.mMaterial.SetTexture("_SSGITemporalGIBuffer", this.giHistory);
    }

    private void SetupCommandBuffer()
    {
        //this.aoRenderTexture = RenderTexture.GetTemporary(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        RenderTargetIdentifier temp = new RenderTargetIdentifier(this.giHistory);

        int ilum = Shader.PropertyToID("_SSGITemporalIlumTexture");
        int flip = Shader.PropertyToID("_SSGITemporalFlipTexture");
        int flop = Shader.PropertyToID("_SSGITemporalFlopTexture");

        this.aoBuffer = new CommandBuffer() { name = "HSSSS.SSGI" };
        
        this.aoBuffer.GetTemporaryRT(ilum, Screen.width / 4, Screen.height / 4, 0, FilterMode.Bilinear, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.aoBuffer.GetTemporaryRT(flip, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.aoBuffer.GetTemporaryRT(flop, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

        this.aoBuffer.Blit(temp, ilum, this.mMaterial, 0);

        this.aoBuffer.Blit(ilum, flip, this.mMaterial, 8);

        this.aoBuffer.Blit(flip, flop, this.mMaterial, 9);
        this.aoBuffer.Blit(flop, flip, this.mMaterial, 10);
        this.aoBuffer.Blit(flip, flop, this.mMaterial, 11);
        this.aoBuffer.Blit(flop, flip, this.mMaterial, 12);

        this.aoBuffer.Blit(flip, flop, this.mMaterial, 13);

        this.aoBuffer.Blit(flop, flip, this.mMaterial, 14);
        this.aoBuffer.Blit(flop, temp);

        this.aoBuffer.Blit(flip, BuiltinRenderTextureType.CameraTarget);

        this.aoBuffer.ReleaseTemporaryRT(ilum);
        this.aoBuffer.ReleaseTemporaryRT(flip);
        this.aoBuffer.ReleaseTemporaryRT(flop);

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

        RenderTexture rt = RenderTexture.active;
        RenderTexture.active = this.giHistory;
        GL.Clear(true, true, Color.clear);
        RenderTexture.active = rt;
    }

    private void RemoveHistoryBuffer()
    {
        this.giHistory.Release();
        this.giHistory = null;
    }
}
