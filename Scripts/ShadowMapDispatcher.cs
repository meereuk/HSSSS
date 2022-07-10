using UnityEngine;
using UnityEngine.Rendering;

namespace HSSSS
{
    [ExecuteInEditMode]
    [RequireComponent(typeof(Light))]
    public class ShadowMapDispatcher : MonoBehaviour
    {
        private Light mLight;
        private CommandBuffer mBuffer;

        private void Awake()
        {
            this.mLight = GetComponent<Light>();
        }

        private void Update()
        {
            Shader.SetGlobalFloat("_DirLightPenumbra", this.mLight.shadowNearPlane);
        }

        private void Reset()
        {
            if (this.mLight != null && this.mLight.type == LightType.Directional)
            {
                this.mLight.RemoveCommandBuffer(LightEvent.AfterShadowMap, this.mBuffer);
                this.InitializeCommandBuffer();
            }
        }

        private void OnEnable()
        {
            if (this.mLight != null && this.mLight.type == LightType.Directional)
            {
                this.InitializeCommandBuffer();
            }
        }

        private void OnDisable()
        {
            if (this.mLight != null && this.mLight.type == LightType.Directional)
            {
                this.mLight.RemoveCommandBuffer(LightEvent.AfterShadowMap, this.mBuffer);
            }
        }

        private void InitializeCommandBuffer()
        {
            RenderTargetIdentifier sourceMap = BuiltinRenderTextureType.CurrentActive;
            int targetMap = Shader.PropertyToID("_CustomShadowMap");

            this.mBuffer = new CommandBuffer();
            this.mBuffer.name = "ShadowMapDispatcher";
            this.mBuffer.SetShadowSamplingMode(sourceMap, ShadowSamplingMode.RawDepth);
            this.mBuffer.GetTemporaryRT(targetMap, 4096, 4096, 0, FilterMode.Bilinear, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
            this.mBuffer.Blit(sourceMap, targetMap);
            this.mBuffer.ReleaseTemporaryRT(targetMap);
            this.mLight.AddCommandBuffer(LightEvent.AfterShadowMap, this.mBuffer);
        }
    }
}
