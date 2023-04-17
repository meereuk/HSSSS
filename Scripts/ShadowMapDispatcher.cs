using UnityEngine;
using UnityEngine.Rendering;

namespace HSSSS
{
    [RequireComponent(typeof(Light))]
    public class ShadowMapDispatcher : MonoBehaviour
    {
        public Light mLight;
        private CommandBuffer mBuffer;

        private void Awake()
        {
        }

        private void Start()
        {
        }

        private void OnEnable()
        { 
            this.mLight = GetComponent<Light>();
            this.InitializeCommandBuffer();
        }

        private void OnDisable()
        {
            //this.mLight.RemoveCommandBuffer(LightEvent.AfterShadowMap, this.mBuffer);
        }

        private void InitializeCommandBuffer()
        {
            this.mBuffer = new CommandBuffer();
            RenderTargetIdentifier sourceMap = BuiltinRenderTextureType.CurrentActive;
            int targetMap = Shader.PropertyToID("_CustomShadowMap");
            this.mBuffer.SetShadowSamplingMode(sourceMap, ShadowSamplingMode.RawDepth);
            this.mBuffer.GetTemporaryRT(targetMap, 4096, 4096, 0, FilterMode.Bilinear, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
            this.mBuffer.Blit(sourceMap, targetMap);
            this.mBuffer.ReleaseTemporaryRT(targetMap);
            this.mLight.AddCommandBuffer(LightEvent.AfterShadowMap, this.mBuffer);
        }
    }
}
