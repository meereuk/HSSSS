using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class ScreenSpaceScattering : MonoBehaviour
{
	private Camera mCamera;

	private CommandBuffer mBuffer;
	private CommandBuffer nBuffer;

	private Shader blitShader;
	private Shader blurShader;
	private Material blitMaterial;
	private Material blurMaterial;

	public Texture2D skinJitter;
	public Texture2D shadowJitter;
	public Texture2D deepScatterLut;

	public void OnEnable()
    {
		this.mCamera = GetComponent<Camera>();
	}

	public void OnDisable()
    {
		this.mCamera.RemoveAllCommandBuffers();
		this.blitMaterial = null;
		this.blurMaterial = null;
		this.blitShader = null;
		this.blurShader = null;
    }

	public void Start ()
	{
		this.SetMaterials();
		this.SetGlobalParams();
		this.InitializeBuffers();
	}

	private void InitializeBuffers()
    {
		int flipRT = Shader.PropertyToID("_FlipRenderTexture");
		int flopRT = Shader.PropertyToID("_FlopRenderTexture");
		int ambiRT = Shader.PropertyToID("_AmbientDiffuseBuffer");

		// override gbuffers
		this.nBuffer = new CommandBuffer() { name = "OverrideGBuffer3" };
		this.nBuffer.GetTemporaryRT(flipRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
		this.nBuffer.GetTemporaryRT(ambiRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

		this.nBuffer.Blit(BuiltinRenderTextureType.CameraTarget, flipRT, this.blitMaterial, 0);
		this.nBuffer.Blit(BuiltinRenderTextureType.CameraTarget, ambiRT, this.blitMaterial, 1);
		this.nBuffer.Blit(ambiRT, BuiltinRenderTextureType.CameraTarget);
		this.nBuffer.ReleaseTemporaryRT(flipRT);
		this.nBuffer.ReleaseTemporaryRT(flopRT);
		this.mCamera.AddCommandBuffer(CameraEvent.BeforeLighting, this.nBuffer);

		// separable blur buffer
		this.mBuffer = new CommandBuffer() { name = "SeparableBlur" };

		this.mBuffer.GetTemporaryRT(flipRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
		this.mBuffer.GetTemporaryRT(flopRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

		// subtract ambient specular
		this.mBuffer.Blit(BuiltinRenderTextureType.CurrentActive, flipRT);

		// separable blur
		for (int iter = 0; iter < 2; iter ++)
        {
			this.mBuffer.Blit(flipRT, flopRT, this.blurMaterial, 1);
			this.mBuffer.Blit(flopRT, flipRT, this.blurMaterial, 2);
        }

		// collect everything
		this.mBuffer.Blit(flipRT, flopRT, this.blurMaterial, 3);
		this.mBuffer.Blit(flopRT, BuiltinRenderTextureType.CameraTarget);
		this.mBuffer.ReleaseTemporaryRT(flipRT);
		this.mBuffer.ReleaseTemporaryRT(flopRT);
		this.mCamera.AddCommandBuffer(CameraEvent.AfterLighting, this.mBuffer);
		
		/*
		this.mBuffer = new CommandBuffer() { name = "ApplySpecularRWTexture" };
		this.mBuffer.GetTemporaryRT(tickRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf);
		this.mBuffer.GetTemporaryRT(tockRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf);
		this.mCamera.AddCommandBuffer(CameraEvent.AfterLighting, this.mBuffer);
		*/
	}
	
	private void SetMaterials()
	{
		this.blitMaterial = new Material(Shader.Find("Hidden/HSSSS/TransmissionBlit"));
		this.blurMaterial = new Material(Shader.Find("Hidden/HSSSS/ScreenSpaceDiffuseBlur"));
		this.blurMaterial.SetTexture("_SkinJitter", skinJitter);
	}

	private void SetGlobalParams()
    {
		Shader.EnableKeyword("_PCSS_ON");
		Shader.EnableKeyword("_SCREENSPACE_SSS");

		Shader.SetGlobalTexture("_ShadowJitterTexture", shadowJitter);
		Shader.SetGlobalTexture("_DeferredTransmissionLut", deepScatterLut);

		Shader.SetGlobalVector("_DeferredSkinParams", new Vector4(1.0f, 1.0f, 1.0f, 1.0f));
		Shader.SetGlobalVector("_DeferredTransmissionParams", new Vector4(0.0f, 1.0f, 1.0f, 1.0f));
	}
}
