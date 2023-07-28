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

    public void OnEnable()
    {
        this.mLight = GetComponent<Light>();
    }

    public void OnDisable()
    {
        /*
        this.mLight.RemoveCommandBuffer(LightEvent.AfterShadowMap, this.mBuffer);
        this.mBuffer = null;
        this.mLight = null;
        */
    }

    public void Update()
    {
        Shader.SetGlobalVector("_PointLightPenumbra", new Vector3(this.searchRadius, this.lightRadius, this.minRadius));
        Shader.SetGlobalInt("_SoftShadowNumIter", quality);
    }

    public void Start()
    {
        /*
        this.mBuffer = new CommandBuffer() { name = "LightParams" };
        this.mBuffer.SetGlobalVector("_PointLightPenumbra", new Vector3(this.searchRadius, this.lightRadius, this.minRadius));
        this.mBuffer.SetGlobalFloat("_SoftShadowNumIter", 6);
        this.mLight.AddCommandBuffer(LightEvent.AfterShadowMap, this.mBuffer);
        */
    }
}