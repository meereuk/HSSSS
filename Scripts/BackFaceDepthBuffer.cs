using UnityEngine;
using System.Collections;
using JetBrains.Annotations;

public class BackFaceDepthBuffer : MonoBehaviour
{
	public Camera mainCamera;

	private Camera mCamera;
    private Shader mShader;
	private RenderTexture mTexture;

	public void OnEnable()
	{
        this.SetUpDepthCamera();
        this.mShader = Shader.Find("Hidden/BackFaceDepth");

        this.mTexture = new RenderTexture(
            Screen.currentResolution.width, Screen.currentResolution.height,
            0, RenderTextureFormat.Depth, RenderTextureReadWrite.Linear);

        this.mTexture.Create();
    }

	public void OnDisable()
	{
		DestroyObject(this.mCamera);
		DestroyImmediate(this.mTexture);

		this.mCamera = null;
		this.mTexture = null;
	}
	
	void Update()
	{
        if (this.mCamera && this.mainCamera)
        {
            this.UpdateDepthCamera();
            
        }
    }

    void LateUpdate()
    {
        this.CaptureDepth();
    }

	private void SetUpDepthCamera()
	{
        if (this.mCamera == null)
        {
            this.mCamera = this.gameObject.AddComponent<Camera>();
        }

        this.mCamera.name = "BackFaceDepthCamera";
        this.mCamera.enabled = false;
        this.mCamera.backgroundColor = new Color(0.0f, 0.0f, 0.0f, 0.0f);
        this.mCamera.clearFlags = CameraClearFlags.SolidColor;
        this.mCamera.renderingPath = RenderingPath.VertexLit;
    }

    private void UpdateDepthCamera()
    {
        this.mCamera.transform.position = this.mainCamera.transform.position;
        this.mCamera.transform.rotation = this.mainCamera.transform.rotation;
        this.mCamera.fieldOfView = this.mainCamera.fieldOfView;
        this.mCamera.nearClipPlane = this.mainCamera.nearClipPlane;
        this.mCamera.farClipPlane = this.mainCamera.farClipPlane;
    }

    private void CaptureDepth()
    {
        /*
        this.mTexture = RenderTexture.GetTemporary(
            Screen.currentResolution.width, Screen.currentResolution.height,
            24, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
            */
        this.mCamera.targetTexture = this.mTexture;
        this.mCamera.RenderWithShader(this.mShader, "");
        Shader.SetGlobalTexture("_BackFaceDepthBuffer", this.mTexture);
        //RenderTexture.ReleaseTemporary(this.mTexture);
    }
}
