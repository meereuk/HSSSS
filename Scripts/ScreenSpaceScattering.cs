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
    }

	public void Start ()
	{
		this.SetGlobalParams();
		this.InitializeBuffers();
	}

	public void Update ()
	{
        Shader.SetGlobalFloat("_SSShadowRayLength", this.rayLength);
        Shader.SetGlobalFloat("_SSShadowRayRadius", this.rayRadius);
        Shader.SetGlobalFloat("_SSShadowDepthBias", this.depthBias);
    }

	private void InitializeBuffers()
    {
		int tickRT = Shader.PropertyToID("_TickRenderTexture");
		int tockRT = Shader.PropertyToID("_TockRenderTexture");
		int ambiRT = Shader.PropertyToID("_AmbientDiffuseBuffer");

		this.nBuffer = new CommandBuffer() { name = "OverrideGBuffer3" };
		this.nBuffer.GetTemporaryRT(tickRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGB32);
		this.nBuffer.GetTemporaryRT(ambiRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf);

		this.nBuffer.Blit(BuiltinRenderTextureType.CameraTarget, tickRT, this.blitMaterial, 0);
		this.nBuffer.Blit(BuiltinRenderTextureType.CameraTarget, ambiRT, this.blitMaterial, 1);
		this.nBuffer.Blit(ambiRT, BuiltinRenderTextureType.CameraTarget);
		this.nBuffer.ReleaseTemporaryRT(tickRT);
		this.mCamera.AddCommandBuffer(CameraEvent.AfterGBuffer, this.nBuffer);

		this.mBuffer = new CommandBuffer() { name = "SeparableBlur" };
		this.mBuffer.GetTemporaryRT(tickRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
		this.mBuffer.GetTemporaryRT(tockRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);

		this.mBuffer.Blit(BuiltinRenderTextureType.CameraTarget, tickRT, this.blurMaterial, 0);

		for (int iter = 0; iter < 2; iter ++)
        {
			this.mBuffer.Blit(tickRT, tockRT, this.blurMaterial, 1);
			this.mBuffer.Blit(tockRT, tickRT, this.blurMaterial, 2);
        }

		this.mBuffer.Blit(tickRT, tockRT, this.blurMaterial, 3);
		this.mBuffer.Blit(tockRT, BuiltinRenderTextureType.CameraTarget);

		this.mBuffer.ReleaseTemporaryRT(tickRT);
		this.mBuffer.ReleaseTemporaryRT(tockRT);
		this.mBuffer.ReleaseTemporaryRT(ambiRT);

		this.mCamera.AddCommandBuffer(CameraEvent.AfterLighting, this.mBuffer);
		
		/*
		this.mBuffer = new CommandBuffer() { name = "ApplySpecularRWTexture" };
		this.mBuffer.GetTemporaryRT(tickRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf);
		this.mBuffer.GetTemporaryRT(tockRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf);
		this.mCamera.AddCommandBuffer(CameraEvent.AfterLighting, this.mBuffer);
		*/
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
		Shader.SetGlobalVector("_DeferredTransmissionParams", new Vector4(1.0f, 1.0f, 1.0f, 1.0f));

		Shader.SetGlobalVector("_PointLightPenumbra", new Vector3(4.0f, 8.0f, 0.0f));
		Shader.SetGlobalVector("_SpotLightPenumbra", new Vector3(8.0f, 8.0f, 0.0f));
		Shader.SetGlobalVector("_DirLightPenumbra", new Vector3(0.0f, 0.0f, 0.5f));

		Shader.SetGlobalFloat("_SSShadowRayLength", 0.04f);
        Shader.SetGlobalFloat("_SSShadowRayRadius", 0.08f);
		Shader.SetGlobalFloat("_SSShadowDepthBias", 0.00f);

		this.blitShader = Shader.Find("Hidden/HSSSS/TransmissionBlit");
		this.blitMaterial = new Material(this.blitShader);

		this.blurShader = Shader.Find("Hidden/HSSSS/ScreenSpaceDiffuseBlur");
		this.blurMaterial = new Material(this.blurShader);
		this.blurMaterial.SetTexture("_SkinJitter", skinJitter);
		this.blurMaterial.SetVector("_DeferredBlurredNormalsParams", new Vector2(2.0f, 40.0f));
	}
}
