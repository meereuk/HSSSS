using UnityEngine;
using UnityEngine.Rendering;

namespace HSSSS
{
    [RequireComponent(typeof(Light))]
    public class ShadowMapDispatcher : MonoBehaviour
    {
        private Light mLight;
        private Shader mShader;
        private Material mMaterial;
        public Camera mCamera;
        public Texture2D jitter;
        private CommandBuffer mBuffer;

        private Matrix4x4 viewMatrix;
        private Matrix4x4 projMatrix;
        private Matrix4x4 viewProjMatrix;


        private void Awake()
        {
            this.mLight = GetComponent<Light>();
            this.mShader = Shader.Find("Hidden/HSSSS/ScreenSpaceContactShadow");
            this.mMaterial = new Material(this.mShader);
            this.mMaterial.SetTexture("_JitterTexture", this.jitter);
            this.mCamera = Camera.main;
        }

        private void Reset()
        {
            if (this.mLight != null)
            {
                this.mLight.RemoveCommandBuffer(LightEvent.AfterShadowMap, this.mBuffer);
                this.InitializeCommandBuffer();
            }
        }

        private void Update()
        {
            this.viewMatrix = mCamera.worldToCameraMatrix;
            this.projMatrix = mCamera.projectionMatrix;
            
            this.mMaterial.SetMatrix("_WorldToViewMatrix", this.viewMatrix);
            this.mMaterial.SetMatrix("_ViewToWorldMatrix", this.viewMatrix.inverse);

            this.mMaterial.SetFloat("_SSCSRayLength", 4.0f);
            this.mMaterial.SetFloat("_SSCSRayRadius", 2.0f);
            this.mMaterial.SetFloat("_SSCSDepthBias", 0.1f);

            this.mMaterial.SetVector("_LightPosition", this.mLight.gameObject.transform.position);
        }

        private void OnEnable()
        {
            if (this.mLight != null)
            {
                this.InitializeCommandBuffer();
            }
        }

        private void OnDisable()
        {
            if (this.mLight != null)
            {
                this.mLight.RemoveCommandBuffer(LightEvent.AfterShadowMap, this.mBuffer);
            }
        }

        private void InitializeCommandBuffer()
        {
            RenderTargetIdentifier sourceMap = BuiltinRenderTextureType.CurrentActive;
            int shadowMap = Shader.PropertyToID("_ScreenSpaceShadowMap");
            int flipRT = Shader.PropertyToID("_SSCSTemporalFlipBuffer");
            int flopRT = Shader.PropertyToID("_SSCSTemporalFlopBuffer");

            this.mBuffer = new CommandBuffer();
            this.mBuffer.name = "SSCSSampler";
            //this.mBuffer.SetShadowSamplingMode(sourceMap, ShadowSamplingMode.RawDepth);
            //this.mBuffer.GetTemporaryRT(flipRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.R8, RenderTextureReadWrite.Linear);
            //this.mBuffer.GetTemporaryRT(flopRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.R8, RenderTextureReadWrite.Linear);
            this.mBuffer.GetTemporaryRT(shadowMap, -1, -1, 0, FilterMode.Point, RenderTextureFormat.R8, RenderTextureReadWrite.Linear);
            this.mBuffer.GetTemporaryRT(flipRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.R8, RenderTextureReadWrite.Linear);
            this.mBuffer.GetTemporaryRT(flopRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.R8, RenderTextureReadWrite.Linear);
            this.mBuffer.Blit(BuiltinRenderTextureType.CurrentActive, flipRT, this.mMaterial, 0);
            this.mBuffer.Blit(flipRT, flopRT, this.mMaterial, 1);
            this.mBuffer.Blit(flopRT, flipRT, this.mMaterial, 2);
            this.mBuffer.Blit(flipRT, shadowMap);
            this.mBuffer.ReleaseTemporaryRT(shadowMap);
            this.mBuffer.ReleaseTemporaryRT(flipRT);
            this.mBuffer.ReleaseTemporaryRT(flopRT);
            this.mLight.AddCommandBuffer(LightEvent.AfterShadowMap, this.mBuffer);
            /*
            this.mBuffer.SetShadowSamplingMode(sourceMap, ShadowSamplingMode.CompareDepths);
            this.mBuffer.SetShadowSamplingMode(targetMap, ShadowSamplingMode.CompareDepths);
            this.mBuffer.GetTemporaryRT(targetMap, 2048, 2048, 0, FilterMode.Bilinear, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
            this.mBuffer.GetTemporaryRT(shadowMap, -1, -1, 0, FilterMode.Bilinear, RenderTextureFormat.RGFloat, RenderTextureReadWrite.Linear);
            this.mBuffer.Blit(sourceMap, targetMap);
            this.mBuffer.Blit(targetMap, shadowMap, this.mMaterial);
            this.mBuffer.ReleaseTemporaryRT(targetMap);
            this.mLight.AddCommandBuffer(LightEvent.AfterShadowMap, this.mBuffer);
            */
        }
    }
}
