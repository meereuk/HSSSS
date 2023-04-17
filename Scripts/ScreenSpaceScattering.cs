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
	public Texture2D iblSpecularLUT;

	public float rayLength;
	public float rayRadius;
	public float depthBias;

	public void Awake()
	{
	}

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
		
		Shader.SetGlobalTexture("_SpecularLUT", this.iblSpecularLUT);
	}

	public void Update ()
	{
        Shader.SetGlobalFloat("_SSShadowRayLength", this.rayLength);
        Shader.SetGlobalFloat("_SSShadowRayRadius", this.rayRadius);
        Shader.SetGlobalFloat("_SSShadowDepthBias", this.depthBias);
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
		this.mCamera.AddCommandBuffer(CameraEvent.AfterGBuffer, this.nBuffer);

		// separable blur buffer

		this.mBuffer = new CommandBuffer() { name = "SeparableBlur" };

		this.mBuffer.GetTemporaryRT(flipRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
		this.mBuffer.GetTemporaryRT(flopRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

		// subtract ambient specular
		this.mBuffer.Blit(null, flipRT, this.blurMaterial, 0);

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
		this.blitShader = Shader.Find("Hidden/HSSSS/TransmissionBlit");
		this.blurShader = Shader.Find("Hidden/HSSSS/ScreenSpaceDiffuseBlur");
		this.blitMaterial = new Material(this.blitShader);
		this.blurMaterial = new Material(this.blurShader);
		this.blurMaterial.SetTexture("_SkinJitter", skinJitter);
		this.blurMaterial.SetVector("_DeferredBlurredNormalsParams", new Vector2(4.0f, 0.0f));
	}

	private void SetGlobalParams()
    {
		Shader.EnableKeyword("_PCSS_ON");
		Shader.EnableKeyword("_PCF_TAPS_64");
		Shader.EnableKeyword("_SCREENSPACE_SSS");
		Shader.EnableKeyword("_MICRODETAILS");
		Shader.EnableKeyword("_RT_SHADOW_HQ");
		Shader.EnableKeyword("_DIR_PCF_ON");

		Shader.SetGlobalTexture("_ShadowJitterTexture", shadowJitter);
		Shader.SetGlobalTexture("_DeferredTransmissionLut", deepScatterLut);

		Shader.SetGlobalVector("_DeferredSkinParams", new Vector4(1.0f, 1.0f, 1.0f, 1.0f));
		Shader.SetGlobalVector("_DeferredTransmissionParams", new Vector4(0.0f, 1.0f, 1.0f, 1.0f));

		Shader.SetGlobalVector("_PointLightPenumbra", new Vector3(2.0f, 2.0f, 0.0f));
		Shader.SetGlobalVector("_SpotLightPenumbra", new Vector3(1.0f, 1.0f, 0.0f));
		Shader.SetGlobalVector("_DirLightPenumbra", new Vector3(4.0f, 4.0f, 0.0f));
	}
}
