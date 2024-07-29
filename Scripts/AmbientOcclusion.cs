using UnityEngine;
using System.Collections;
using UnityEngine.Rendering;

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

    private static Mesh quad = null;

    public void OnEnable()
    {
        this.mCamera = GetComponent<Camera>();
        this.mMaterial = new Material(Shader.Find("Hidden/HSSSS/AmbientOcclusion"));
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
        this.mMaterial.SetFloat("_SSAORayLength", SSAORayLength);
        this.mMaterial.SetFloat("_SSAOIntensity", SSAOIntensity);
        this.mMaterial.SetInt(  "_SSAORayStride", SSAORayStride);
        this.mMaterial.SetInt(  "_SSAOScreenDiv", SSAOScreenDiv);
        this.mMaterial.SetInt(  "_FrameCount", Time.frameCount);
        this.mMaterial.SetInt(  "_SSAOUseSparse", 0);

        this.mMaterial.SetTexture("_BlueNoise", this.BlueNoise);
    }

    private void SetupCommandBuffer()
    {
        int zbuf = Shader.PropertyToID("_HierachicalZBuffer0");
        int ZB1 = Shader.PropertyToID("_HierachicalZBuffer1");
        int ZB2 = Shader.PropertyToID("_HierachicalZBuffer2");
        int ZB3 = Shader.PropertyToID("_HierachicalZBuffer3");
        int flip = Shader.PropertyToID("_SSAOFlipRenderTexture");
        int flop = Shader.PropertyToID("_SSAOFlopRenderTexture");

        this.aoBuffer = new CommandBuffer() { name = "HSSSS.SSAO" };

        this.aoBuffer.GetTemporaryRT(zbuf, -1, -1, 0, FilterMode.Bilinear, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
        this.aoBuffer.GetTemporaryRT(ZB1, Screen.width / 2, Screen.height / 2, 0, FilterMode.Bilinear, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
        this.aoBuffer.GetTemporaryRT(ZB2, Screen.width / 4, Screen.height / 4, 0, FilterMode.Bilinear, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
        this.aoBuffer.GetTemporaryRT(ZB3, Screen.width / 8, Screen.height / 8, 0, FilterMode.Bilinear, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);

        this.aoBuffer.GetTemporaryRT(flip, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
        this.aoBuffer.GetTemporaryRT(flop, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);

        this.aoBuffer.Blit(BuiltinRenderTextureType.CurrentActive, zbuf, this.mMaterial, 0);

        this.aoBuffer.Blit(zbuf, ZB1, this.mMaterial, 1);
        this.aoBuffer.Blit(ZB1 , ZB2, this.mMaterial, 1);
        this.aoBuffer.Blit(ZB2 , ZB3, this.mMaterial, 1);

        this.aoBuffer.Blit(zbuf, flip, this.mMaterial, 5);

        this.aoBuffer.Blit(flip, flop, this.mMaterial, 6);
        this.aoBuffer.Blit(flop, flip, this.mMaterial, 7);

        /*
        this.aoBuffer.Blit(flip, flop, this.mMaterial, 8);
        this.aoBuffer.Blit(flop, flip, this.mMaterial, 9);
        this.aoBuffer.Blit(flip, flop, this.mMaterial, 8);
        this.aoBuffer.Blit(flop, flip, this.mMaterial, 9);
        */

        this.aoBuffer.Blit(flip, BuiltinRenderTextureType.CameraTarget, this.mMaterial, 13);

        this.aoBuffer.ReleaseTemporaryRT(zbuf);
        this.aoBuffer.ReleaseTemporaryRT(ZB1);
        this.aoBuffer.ReleaseTemporaryRT(ZB2);
        this.aoBuffer.ReleaseTemporaryRT(ZB3);

        this.aoBuffer.ReleaseTemporaryRT(flip);
        this.aoBuffer.ReleaseTemporaryRT(flop);

        this.mCamera.AddCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, this.aoBuffer);
    }

    private void RemoveCommandBuffer()
    {
        this.mCamera.RemoveCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, this.aoBuffer);
        this.aoBuffer = null;
    }
}
