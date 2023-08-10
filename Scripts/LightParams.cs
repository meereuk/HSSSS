using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
[RequireComponent(typeof(Light))]
public class LightParams : MonoBehaviour
{
    private Light mLight;
    private CommandBuffer mBuffer;

    public int quality;
    public float searchRadius;
    public float lightRadius;
    public float minRadius;

    public Texture2D blueNoise;

    public void OnEnable()
    {
        this.mLight = GetComponent<Light>();

        if (this.mLight.type != LightType.Point)
        {
            this.SetupCommandBuffer();
        }
    }

    public void OnDisable()
    {
        if (this.mLight.type != LightType.Point)
        {
            this.RemoveCommandBuffer();
        }

        this.mLight = null;
    }

    public void Update()
    {
        switch (this.mLight.type)
        {
            case LightType.Point:
                Shader.SetGlobalVector("_PointLightPenumbra", new Vector3(this.searchRadius, this.lightRadius, this.minRadius));
                break;

            case LightType.Spot:
                Shader.SetGlobalVector("_SpotLightPenumbra", new Vector3(this.searchRadius, this.lightRadius, this.minRadius));
                break;

            case LightType.Directional:
                Shader.SetGlobalVector("_DirLightPenumbra", new Vector3(this.searchRadius, this.lightRadius, this.minRadius));
                break;

            default:
                break;
        }

        Shader.SetGlobalInt("_SoftShadowNumIter", quality);
        Shader.SetGlobalTexture("_BlueNoise", blueNoise);
    }

    private void SetupCommandBuffer()
    {
        RenderTargetIdentifier source = BuiltinRenderTextureType.CurrentActive;
        int target = Shader.PropertyToID("_CustomShadowMap");

        this.mBuffer = new CommandBuffer() { name = "HSSSS.SMDispatcher" };
        this.mBuffer.SetShadowSamplingMode(source, ShadowSamplingMode.RawDepth);
        this.mBuffer.GetTemporaryRT(target, 4096, 4096, 0, FilterMode.Point, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
        this.mBuffer.Blit(source, target);
        this.mBuffer.ReleaseTemporaryRT(target);
        
        this.mLight.AddCommandBuffer(LightEvent.AfterShadowMap, this.mBuffer);
    }

    private void RemoveCommandBuffer()
    {
        this.mLight.RemoveCommandBuffer(LightEvent.AfterShadowMap, this.mBuffer);
        this.mBuffer = null;
    }
}