using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class ScreenSpaceScattering : MonoBehaviour
{
	private Camera mCamera;
	private CommandBuffer mBuffer;

	public void OnEnable()
    {
		this.mCamera = GetComponent<Camera>();
	}

	public void OnDisable()
    {
		this.mCamera.RemoveAllCommandBuffers();
    }

	public void Start ()
	{
		this.InitializeBuffers();
	}

	private void InitializeBuffers()
    {
		Shader.EnableKeyword("_SCREENSPACE_SSS");

		Material material = new Material(Shader.Find("Hidden/HSSSS/SSSMainPass"));

		int flipRT = Shader.PropertyToID("_FlipRenderTexture");
		int flopRT = Shader.PropertyToID("_FlopRenderTexture");

		// separable blur buffer
		this.mBuffer = new CommandBuffer() { name = "SeparableBlur" };

		this.mBuffer.GetTemporaryRT(flipRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
		this.mBuffer.GetTemporaryRT(flopRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

		// subtract ambient specular
		this.mBuffer.Blit(BuiltinRenderTextureType.CurrentActive, flipRT, material, 0);
		this.mBuffer.Blit(flipRT, flopRT, material, 3);
		this.mBuffer.Blit(flopRT, BuiltinRenderTextureType.CameraTarget);

		this.mCamera.AddCommandBuffer(CameraEvent.AfterLighting, this.mBuffer);
	}
}
