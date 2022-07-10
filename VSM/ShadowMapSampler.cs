using UnityEngine;
using UnityEngine.Rendering;

namespace HSSSS
{
    [ExecuteInEditMode]
    [RequireComponent(typeof(Light))]
    public class ShadowMapSampler : MonoBehaviour
    {
        private Light mLight;
        private CommandBuffer buffer;

        [SerializeField]
        public Texture2D jitter;

        private void Awake()
        {
            this.mLight = GetComponent<Light>();
        }

        private void Update()
        {
            Shader.SetGlobalFloat("_DirLightPenumbra", this.mLight.shadowNearPlane);
            Shader.SetGlobalTexture("_ShadowJitter", this.jitter);
        }

        private void OnEnable()
        {
            Shader.EnableKeyword("_PCF_TAPS_64");
        }

        private void OnDisable()
        {
            Shader.DisableKeyword("_PCF_TAPS_64");
        }
    }
}
