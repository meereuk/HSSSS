using UnityEngine;
using UnityEngine.Rendering;
using System.Collections;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class AlternativeDeferredRendering : MonoBehaviour
{
	private Camera mCamera;
	private CommandBuffer mBuffer;

	private Shader mShader;
	private Material mMaterial;

	private static Mesh tri = null;

	public void OnEnable()
	{
		this.mCamera = GetComponent<Camera>();
		this.mShader = Shader.Find("Hidden/HSSSS/Deferred Shading");
		this.mMaterial = new Material(this.mShader);

		tri = new Mesh();

		tri.vertices = new Vector3[]
		{
			new Vector3(-1.0f, -1.0f, 0.0f),
            new Vector3(-1.0f,  3.0f, 0.0f),
            new Vector3( 3.0f, -1.0f, 0.0f)	
		};

		tri.triangles = new int[] { 0, 1, 2 };
	}

	public void OnDisable()
	{
		this.mCamera.RemoveAllCommandBuffers();

		this.mCamera = null;
		this.mShader = null;
		this.mMaterial = null;
	}

	public void Start()
	{
		int rt = Shader.PropertyToID("_CameraDiffuseBufferTexture");

		this.mBuffer = new CommandBuffer() { name = "AlternativeDeferredRendering"};
		this.mBuffer.GetTemporaryRT(rt, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

		//this.mBuffer.SetRenderTarget(rt);
		this.mBuffer.DrawMesh(tri, Matrix4x4.identity, this.mMaterial, 0, 0);

		this.mBuffer.ReleaseTemporaryRT(rt);
		this.mCamera.AddCommandBuffer(CameraEvent.AfterLighting, this.mBuffer);
	}
}
