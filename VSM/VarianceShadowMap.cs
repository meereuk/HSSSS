using UnityEngine;
using UnityEngine.Rendering;

namespace HSSSS
{
    [ExecuteInEditMode]
    [RequireComponent(typeof(Light))]
    public class VarianceShadowMap : MonoBehaviour
    {
        private Light mLight;
        private Shader depthShader;
        private Material depthMaterial;
        private CommandBuffer buffer;

        private LightType lightType;
        private int resolution;

        [SerializeField]
        public Texture2D jitter;

        private void Awake()
        {
            this.mLight = GetComponent<Light>();

            if (this.mLight != null)
            {
                this.lightType = this.mLight.type;
                
                switch (this.lightType)
                {
                    case LightType.Directional:
                        this.resolution = 4096;
                        break;

                    case LightType.Spot:
                        this.resolution = 2048;
                        break;

                    case LightType.Point:
                        this.resolution = 1024;
                        break;

                    default:
                        this.resolution = 4096;
                        break;
                }
            }

            depthShader = Shader.Find("Hidden/VSM");
            depthMaterial = new Material(depthShader);
        }

        private void Update()
        {
            if (this.mLight != null)
            {
                this.SetPenumbraSize();
            }
            depthMaterial.SetTexture("_ShadowJitter", jitter);
        }

        private void Reset()
        {
            this.DestroyCommandBuffer();
            this.InitializeCommandBuffer();
        }

        private void OnEnable()
        {
            this.InitializeCommandBuffer();
        }

        private void OnDisable()
        {
            this.DestroyCommandBuffer();
        }

        private void InitializeCommandBuffer()
        {
            if (this.mLight != null)
            {
                if (this.lightType == LightType.Point)
                {
                    this.PointLightCommandBuffer();
                }

                else
                {
                    this.OtherLightCommandBuffer();
                }
            }
        }

        private void DestroyCommandBuffer()
        {
            if (this.mLight != null)
            {
                mLight.RemoveAllCommandBuffers();
            }
        }

        private void OtherLightCommandBuffer()
        {
            RenderTargetIdentifier sourceID = BuiltinRenderTextureType.CurrentActive;
            int depthRT = Shader.PropertyToID("_DepthBufferTexture");
            int blurXRT = Shader.PropertyToID("_BlurXBufferTexture");
            int blurYRT = Shader.PropertyToID("_BlurYBufferTexture");

            this.buffer = new CommandBuffer();
            // Sampling depth & depth square
            this.buffer.GetTemporaryRT(depthRT, this.resolution, this.resolution, 0, FilterMode.Trilinear, RenderTextureFormat.ARGBFloat);
            this.buffer.Blit(sourceID, depthRT, depthMaterial, 0);
            // Gaussian blur with x-axis
            this.buffer.GetTemporaryRT(blurXRT, this.resolution, this.resolution, 0, FilterMode.Trilinear, RenderTextureFormat.ARGBFloat);
            this.buffer.Blit(depthRT, blurXRT, depthMaterial, 1);
            // Gaussian blur with y-axis
            this.buffer.GetTemporaryRT(blurYRT, this.resolution, this.resolution, 0, FilterMode.Trilinear, RenderTextureFormat.ARGBFloat);
            this.buffer.Blit(blurXRT, blurYRT, depthMaterial, 2);
            //
            this.buffer.SetGlobalTexture("_CustomShadowMap", blurYRT);
            //
            //
            this.buffer.ReleaseTemporaryRT(depthRT);
            this.buffer.ReleaseTemporaryRT(blurXRT);
            this.buffer.ReleaseTemporaryRT(blurYRT);
            mLight.AddCommandBuffer(LightEvent.AfterShadowMap, this.buffer);
        }

        private void PointLightCommandBuffer()
        {
            RenderTargetIdentifier sourceID = BuiltinRenderTextureType.CurrentActive;
            this.buffer = new CommandBuffer();
            this.buffer.SetGlobalTexture("_CustomShadowMap", sourceID);
            mLight.AddCommandBuffer(LightEvent.AfterShadowMap, this.buffer);
        }

        private void SetPenumbraSize()
        {
            if (this.lightType == LightType.Directional)
            {
                this.depthMaterial.SetFloat("_Penumbra", this.mLight.shadowNearPlane);
            }

            if (this.lightType == LightType.Spot)
            {
                this.depthMaterial.SetFloat("_Penumbra", this.mLight.shadowNormalBias * 3.33f);
            }
        }
    }
}

/*
[ExecuteInEditMode]
[RequireComponent(typeof(Light))]
public class DrawShadowMap : MonoBehaviour
{
    private Light mLight;
    private Camera mCamera;
    private GameObject objCamera;

    private Light m_Light;
    //private Camera m_Camera;
    private Material m_Material;
    private RenderTexture shadowMap;

    [SerializeField]
    public Shader m_Shader;
    public RenderTexture RT;

    private void Awake()
    {
        this.mLight = GetComponent<Light>();
        this.m_Light = GetComponent<Light>();
        this.m_Camera = gameObject.AddComponent<Camera>();
        this.m_Camera.backgroundColor = new Color(0, 0, 0, 0);
        this.m_Camera.clearFlags = CameraClearFlags.SolidColor;
    }

    private void Start()
    {
        if (this.m_Light == null)
        {
            Debug.Log("No Light Found!");
        }

        else
        {
            Debug.Log("#### Found " + this.m_Light.name);


            if (this.m_Light.type == LightType.Spot)
            {
                m_Material = new Material(m_Shader);

                shadowMap = new RenderTexture(2048, 2048, 16, RenderTextureFormat.RGFloat);
                shadowMap.filterMode = FilterMode.Point;
                shadowMap.wrapMode = TextureWrapMode.Clamp;
                shadowMap.isPowerOfTwo = true;

                RenderTargetIdentifier sourceID = BuiltinRenderTextureType.CurrentActive;
                RenderTargetIdentifier destinationID = new RenderTargetIdentifier(shadowMap);

                int depthBuffer = Shader.PropertyToID("_CustomShadowMapBuffer1");
                int blurBuffer = Shader.PropertyToID("_CustomShadowMapBuffer2");

                CommandBuffer buffer = new CommandBuffer();
                buffer.SetShadowSamplingMode(sourceID, ShadowSamplingMode.RawDepth);
                buffer.GetTemporaryRT(depthBuffer, 2048, 2048, 0, FilterMode.Point, RenderTextureFormat.RGFloat);
                buffer.GetTemporaryRT(blurBuffer, 2048, 2048, 0, FilterMode.Point, RenderTextureFormat.RGFloat);
                buffer.Blit(sourceID, depthBuffer, m_Material, 0);
                buffer.Blit(depthBuffer, blurBuffer, m_Material, 1);
                buffer.Blit(blurBuffer, destinationID, m_Material, 2);
                buffer.SetGlobalTexture("_ShadowMapTex", shadowMap);
                m_Light.AddCommandBuffer(LightEvent.AfterShadowMap, buffer);
            }

            else if (this.m_Light.type == LightType.Point)
            {
                shadowMap = new RenderTexture(1024, 1024, 16, RenderTextureFormat.RGFloat);
                shadowMap.isCubemap = true;

                RenderTargetIdentifier sourceID = BuiltinRenderTextureType.CurrentActive;
                RenderTargetIdentifier destinationID = new RenderTargetIdentifier(shadowMap);

                CommandBuffer buffer = new CommandBuffer();
                buffer.SetShadowSamplingMode (sourceID, ShadowSamplingMode.RawDepth);
                buffer.SetRenderTarget(destinationID, 0, CubemapFace.PositiveX);
                buffer.Blit(sourceID, destinationID);
                buffer.SetGlobalTexture("_ShadowMapTex", shadowMap);
                m_Light.AddCommandBuffer (LightEvent.AfterShadowMap, buffer);
            }
        }
    }
}
*/