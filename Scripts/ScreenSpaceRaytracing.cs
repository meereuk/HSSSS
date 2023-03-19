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
        //this.mShader = Shader.Find("Hidden/ScreenSpaceRayTracing");
        this.mShader = Shader.Find("Hidden/ScreenSpaceBentNormal");
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
        int tempRT = Shader.PropertyToID("_BentNormalTexture");

        this.mBuffer = new CommandBuffer() { name = "ScreenSpaceBentNormal" };
        this.mBuffer.GetTemporaryRT(tempRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

        this.mBuffer.Blit(BuiltinRenderTextureType.CameraTarget, tempRT, this.mMaterial);
        this.mBuffer.ReleaseTemporaryRT(tempRT);

        this.mCamera.AddCommandBuffer(CameraEvent.AfterGBuffer, this.mBuffer);
        
        /*
        int tickRT = Shader.PropertyToID("_SSRTGITickRT");
        int tockRT = Shader.PropertyToID("_SSRTGITockRT");

        this.mBuffer = new CommandBuffer() { name = "ScreenSpaceRayTracing" };
        this.mBuffer.GetTemporaryRT(tickRT,
            -1, -1,//Screen.currentResolution.width / 2, Screen.currentResolution.height / 2,
            0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        this.mBuffer.GetTemporaryRT(tockRT,
            -1, -1, //Screen.currentResolution.width / 2, Screen.currentResolution.height / 2,
            0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

        this.mBuffer.Blit(BuiltinRenderTextureType.CameraTarget, tickRT, this.mMaterial, 0);
        
        this.mBuffer.Blit(tickRT, tockRT, this.mMaterial, 1);
        this.mBuffer.Blit(tockRT, tickRT, this.mMaterial, 1);
        this.mBuffer.Blit(tickRT, tockRT, this.mMaterial, 1);
        this.mBuffer.Blit(tockRT, tickRT, this.mMaterial, 1);
        this.mBuffer.Blit(tickRT, tockRT, this.mMaterial, 1);
        this.mBuffer.Blit(tockRT, tickRT, this.mMaterial, 1);
        this.mBuffer.Blit(tickRT, tockRT, this.mMaterial, 1);
        this.mBuffer.Blit(tockRT, tickRT, this.mMaterial, 1);

        this.mBuffer.Blit(tickRT, tockRT, this.mMaterial, 2);
        this.mBuffer.Blit(tockRT, tickRT, this.mMaterial, 3);
        this.mBuffer.Blit(tickRT, tockRT, this.mMaterial, 2);
        this.mBuffer.Blit(tockRT, tickRT, this.mMaterial, 3);

        this.mBuffer.Blit(tickRT, tockRT, this.mMaterial, 2);
        this.mBuffer.Blit(tockRT, tickRT, this.mMaterial, 3);
        this.mBuffer.Blit(tickRT, tockRT, this.mMaterial, 2);
        this.mBuffer.Blit(tockRT, tickRT, this.mMaterial, 3);

        this.mBuffer.Blit(tickRT, tockRT, this.mMaterial, 4);
        this.mBuffer.Blit(tockRT, BuiltinRenderTextureType.CameraTarget);

        this.mBuffer.ReleaseTemporaryRT(tickRT);
        this.mBuffer.ReleaseTemporaryRT(tockRT);
        */

        //this.mCamera.AddCommandBuffer(CameraEvent.AfterGBuffer, this.mBuffer);
    }

    private void RemoveCommandBuffer()
    {
        this.mCamera.RemoveCommandBuffer(CameraEvent.AfterGBuffer, this.mBuffer);
        this.mBuffer = null;
    }
}
