using UnityEngine;
using UnityEngine.Rendering;

namespace HSSSS
{
    public class ContactShadowSampler : MonoBehaviour
    {
        public Light mLight;
        public Camera mCamera;

        private Material mMaterial;
        private CommandBuffer mBuffer;

        private Matrix4x4 WorldToView;
        private Matrix4x4 ViewToWorld;

        private void Awake()
        {
            this.mLight = GetComponent<Light>();
            this.mMaterial = new Material(Shader.Find("Hidden/HSSSS/ScreenSpaceContactShadow"));
            this.mCamera = Camera.main;
        }

        private void Start()
        {
            this.SetupCommandBuffer();
        }

        private void OnDisable()
        {
            this.DestroyCommandBuffer();
        }

        private void Update()
        {
            this.mMaterial.SetFloat("_SSCSRayLength", 2.0f);
            this.mMaterial.SetFloat("_SSCSRayRadius", 4.0f);

            this.mMaterial.SetMatrix("_WorldToViewMatrix", mCamera.worldToCameraMatrix);
            this.mMaterial.SetMatrix("_ViewToWorldMatrix", mCamera.worldToCameraMatrix.inverse);

            this.mMaterial.SetMatrix("_ViewToClipMatrix", mCamera.projectionMatrix);
            this.mMaterial.SetMatrix("_ClipToViewMatrix", mCamera.projectionMatrix.inverse);

            this.mMaterial.SetVector("_LightPosition", this.mLight.gameObject.transform.position);
        }

        private void SetupCommandBuffer()
        {
            int flipRT = Shader.PropertyToID("_SSCSTemporalFlipBuffer");
            int flopRT = Shader.PropertyToID("_SSCSTemporalFlopBuffer");

            int shadowMap = Shader.PropertyToID("_ScreenSpaceShadowMap");

            this.mBuffer = new CommandBuffer() { name = "HSSSS.SSCSSampler"};
            this.mBuffer.GetTemporaryRT(shadowMap, -1, -1, 0, FilterMode.Point, RenderTextureFormat.R8, RenderTextureReadWrite.Linear);
            this.mBuffer.GetTemporaryRT(flipRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.R8, RenderTextureReadWrite.Linear);
            this.mBuffer.GetTemporaryRT(flopRT, -1, -1, 0, FilterMode.Point, RenderTextureFormat.R8, RenderTextureReadWrite.Linear);
            this.mBuffer.Blit(BuiltinRenderTextureType.CurrentActive, flipRT, this.mMaterial, 0);

            this.mBuffer.Blit(flipRT, flopRT, this.mMaterial, 1);
            this.mBuffer.Blit(flopRT, flipRT, this.mMaterial, 2);
            this.mBuffer.Blit(flipRT, flopRT, this.mMaterial, 1);
            this.mBuffer.Blit(flopRT, flipRT, this.mMaterial, 2);

            this.mBuffer.Blit(flipRT, shadowMap);
            this.mBuffer.ReleaseTemporaryRT(flipRT);
            this.mBuffer.ReleaseTemporaryRT(flopRT);
            this.mBuffer.ReleaseTemporaryRT(shadowMap);
            this.mLight.AddCommandBuffer(LightEvent.AfterShadowMap, this.mBuffer);
        }

        private void DestroyCommandBuffer()
        {
            this.mLight.RemoveCommandBuffer(LightEvent.AfterShadowMap, this.mBuffer);
            this.mBuffer = null;
        }
    }
}