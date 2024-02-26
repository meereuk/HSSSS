using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class ScreenSpaceScattering : MonoBehaviour
{
	private Camera mCamera;
	private CommandBuffer copyBuffer;
	private CommandBuffer blurBuffer;

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

		Material prePass = new Material(Shader.Find("Hidden/HSSSS/SSSPrePass"));
		Material mainPass = new Material(Shader.Find("Hidden/HSSSS/SSSMainPass"));

		int copyRT = Shader.PropertyToID("_DeferredTransmissionBuffer");
		int flipRT = Shader.PropertyToID("_TemporaryFlipRenderTexture");
		int flopRT = Shader.PropertyToID("_TemporaryFlopRenderTexture");

		this.copyBuffer = new CommandBuffer() { name = "HSSSS.SSSPrePass" };
		this.copyBuffer.GetTemporaryRT(copyRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.R8, RenderTextureReadWrite.Linear);
		this.copyBuffer.Blit(BuiltinRenderTextureType.CameraTarget, copyRT, prePass, 0);
		this.mCamera.AddCommandBuffer(CameraEvent.BeforeLighting, this.copyBuffer);

		this.blurBuffer = new CommandBuffer() { name = "HSSSS.SSSMainPass" };
		this.blurBuffer.GetTemporaryRT(flipRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
		this.blurBuffer.GetTemporaryRT(flopRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

		this.blurBuffer.Blit(BuiltinRenderTextureType.CurrentActive, flipRT, mainPass, 0);
		this.blurBuffer.Blit(flipRT, flopRT, mainPass, 3);
		this.blurBuffer.Blit(flopRT, BuiltinRenderTextureType.CameraTarget);

		this.blurBuffer.ReleaseTemporaryRT(flipRT);
		this.blurBuffer.ReleaseTemporaryRT(flopRT);
		this.blurBuffer.ReleaseTemporaryRT(copyRT);

		this.mCamera.AddCommandBuffer(CameraEvent.AfterLighting, this.blurBuffer);
	}
}
