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
    public float SSAORayLength;
    public float SSAOMeanDepth;
    public float SSAOFadeDepth;
    public int   SSAORayStride;
    public int   SSAOScreenDiv;
    public Texture2D BlueNoise;

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
    private RenderTexture zbHistory;

    public void OnEnable()
    {
        this.mCamera = GetComponent<Camera>();
        this.mMaterial = new Material(Shader.Find("Hidden/HSSSS/AmbientOcclusion"));
        this.mMaterial.SetTexture("_BlueNoise", this.BlueNoise);
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

        this.mMaterial.SetFloat("_SSAOFadeDepth", SSAOFadeDepth);
        this.mMaterial.SetFloat("_SSAOMeanDepth", SSAOMeanDepth);
        this.mMaterial.SetFloat("_SSAORayLength", SSAORayLength);
        this.mMaterial.SetFloat("_SSAOIntensity", SSAOIntensity);
        this.mMaterial.SetInt(  "_SSAORayStride", SSAORayStride);
        this.mMaterial.SetInt(  "_SSAOScreenDiv", SSAOScreenDiv);
        this.mMaterial.SetInt(  "_FrameCount", Time.frameCount);

        this.mMaterial.SetTexture("_BlueNoise", this.BlueNoise);
    }

    private void SetupCommandBuffer()
    {
        int flip = Shader.PropertyToID("_SSAOFlipRenderTexture");
        int flop = Shader.PropertyToID("_SSAOFlopRenderTexture");
        int zbuf = Shader.PropertyToID("_FuckingMoronsUnityDev");

        this.aoBuffer = new CommandBuffer() { name = "HSSSS.SSAO" };

        this.aoBuffer.GetTemporaryRT(flip, Screen.width, Screen.height, 0, FilterMode.Point, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
        this.aoBuffer.GetTemporaryRT(flop, Screen.width, Screen.height, 0, FilterMode.Point, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
        this.aoBuffer.GetTemporaryRT(zbuf, Screen.width, Screen.height, 0, FilterMode.Bilinear, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);

        this.aoBuffer.Blit(BuiltinRenderTextureType.CurrentActive, zbuf, this.mMaterial, 0);

        this.aoBuffer.Blit(zbuf, flip, this.mMaterial, 8);
        this.aoBuffer.Blit(flip, flop, this.mMaterial, 9);

        this.aoBuffer.Blit(flop, flip, this.mMaterial, 10);
        this.aoBuffer.Blit(flip, flop, this.mMaterial, 11);
        this.aoBuffer.Blit(flop, flip, this.mMaterial, 12);
        this.aoBuffer.Blit(flip, flop);

        this.aoBuffer.Blit(flop, flip, this.mMaterial, 17);
        this.aoBuffer.Blit(flip, BuiltinRenderTextureType.CameraTarget);

        //this.aoBuffer.Blit(flop, depth, this.mMaterial, 17);

        this.mCamera.AddCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, this.aoBuffer);
    }

    private void RemoveCommandBuffer()
    {
        this.mCamera.RemoveCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, this.aoBuffer);
        this.aoBuffer = null;
    }

        private void SetUpHistoryBuffer()
    {
        this.aoHistory = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.aoHistory.filterMode = FilterMode.Bilinear;
        this.aoHistory.Create();

        this.zbHistory = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
        this.zbHistory.Create();

        RenderTexture rt = RenderTexture.active;
        RenderTexture.active = this.aoHistory;
        GL.Clear(true, true, Color.clear);
        RenderTexture.active = this.zbHistory;
        GL.Clear(true, true, Color.clear);
        RenderTexture.active = rt;
    }

    private void RemoveHistoryBuffer()
    {
        this.aoHistory.Release();
        this.zbHistory.Release();
        this.aoHistory = null;
        this.zbHistory = null;
    }
}
