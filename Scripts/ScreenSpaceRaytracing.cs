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
    private Matrix4x4 viewMatrix;
    private Matrix4x4 projMatrix;
    private Matrix4x4 viewProjMatrix;
    private CommandBuffer mBuffer;

    public void OnEnable()
    {
        this.mCamera = GetComponent<Camera>();
        this.mShader = Shader.Find("Hidden/ScreenSpaceRayTracing");

        this.mMaterial = new Material(this.mShader);
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
        this.viewMatrix = mCamera.worldToCameraMatrix;
        this.projMatrix = GL.GetGPUProjectionMatrix(mCamera.projectionMatrix, false);
        this.viewProjMatrix = this.projMatrix * mCamera.worldToCameraMatrix;

        this.mMaterial.SetMatrix("_MATRIX_V", this.viewMatrix);
        this.mMaterial.SetMatrix("_MATRIX_P", this.projMatrix);
        this.mMaterial.SetMatrix("_MATRIX_VP", this.viewProjMatrix);

        this.mMaterial.SetMatrix("_MATRIX_IV", this.viewMatrix.inverse);
        this.mMaterial.SetMatrix("_MATRIX_IP", this.projMatrix.inverse);
        this.mMaterial.SetMatrix("_MATRIX_IVP", this.viewProjMatrix.inverse);
    }

    private void SetupCommandBuffer()
    {
        int tickRT = Shader.PropertyToID("_SSRTGITickRT");
        int tockRT = Shader.PropertyToID("_SSRTGITockRT");

        this.mBuffer = new CommandBuffer() { name = "ScreenSpaceRayTracing" };
        this.mBuffer.GetTemporaryRT(tickRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.mBuffer.GetTemporaryRT(tockRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

        this.mBuffer.Blit(BuiltinRenderTextureType.CameraTarget, tickRT, this.mMaterial);
        this.mBuffer.Blit(tickRT, tockRT, this.mMaterial);
        this.mBuffer.Blit(tockRT, tickRT, this.mMaterial);
        this.mBuffer.Blit(tickRT, tockRT, this.mMaterial);
        this.mBuffer.Blit(tockRT, BuiltinRenderTextureType.CameraTarget);

        this.mBuffer.ReleaseTemporaryRT(tickRT);

        this.mCamera.AddCommandBuffer(CameraEvent.AfterLighting, this.mBuffer);
    }

    private void RemoveCommandBuffer()
    {
        this.mCamera.RemoveCommandBuffer(CameraEvent.AfterLighting, this.mBuffer);
        this.mBuffer = null;
    }
}
