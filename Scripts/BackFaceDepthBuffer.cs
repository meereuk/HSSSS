using UnityEngine;
using System.Collections;
using JetBrains.Annotations;

public class BackFaceDepthBuffer : MonoBehaviour
{
	public Camera mainCamera;

	private Camera mCamera;
    private Shader mShader;
	private RenderTexture mTexture;

    private GameObject mObject;

	public void OnEnable()
	{
        this.SetUpDepthCamera();
        this.mShader = Shader.Find("HSSSS/TangentRenderer");
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
    }

    void OnPreCull()
    {
        this.mTexture = RenderTexture.GetTemporary(
            Screen.currentResolution.width, Screen.currentResolution.height,
            16, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);

/*
        this.mTexture = new RenderTexture(
            Screen.currentResolution.width, Screen.currentResolution.height,
            0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);

        this.mTexture.Create();
*/

        this.CaptureDepth();
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(this.mTexture, destination);
        RenderTexture.ReleaseTemporary(this.mTexture);
        //this.mTexture.Release();
    }

	private void SetUpDepthCamera()
	{
        this.mObject = new GameObject("SecondaryCamera");
        this.mCamera = this.mObject.AddComponent<Camera>();

        if (this.mCamera == null)
        {
            this.mCamera = new Camera();
        }

        this.mCamera.name = "BackFaceDepthCamera";
        this.mCamera.enabled = false;
        this.mCamera.backgroundColor = new Color(0.0f, 0.0f, 0.0f, 0.0f);
        this.mCamera.clearFlags = CameraClearFlags.SolidColor;
        this.mCamera.renderingPath = RenderingPath.Forward;
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
        this.mCamera.targetTexture = this.mTexture;
        this.mCamera.RenderWithShader(this.mShader, "");
        Shader.SetGlobalTexture("_BackFaceDepthBuffer", this.mTexture);
    }
}
