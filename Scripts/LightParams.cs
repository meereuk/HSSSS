using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
[RequireComponent(typeof(Light))]
public class LightParams : MonoBehaviour
{
    private Light mLight;
    private Material mMaterial;
    private CommandBuffer mBuffer;
    private CommandBuffer nBuffer;

    public Shader mShader;
    public Camera mCamera;

    private Matrix4x4 WorldToView;
    private Matrix4x4 ViewToWorld;

    private Matrix4x4 ViewToClip;
    private Matrix4x4 ClipToView;

    private int lightType;

    public void OnEnable()
    {
        this.mLight = GetComponent<Light>();
        this.mMaterial = new Material(mShader);

        switch(this.mLight.type)
        {
            case LightType.Point:
                lightType = 0;
                this.mMaterial.EnableKeyword("POINT");
                break;
            
            case LightType.Spot:
                lightType = 1;
                this.mMaterial.EnableKeyword("SPOT");
                break;

            case LightType.Directional:
                lightType = 2;
                this.mMaterial.EnableKeyword("DIRECTIONAL");
                break;

            default:
                lightType = 0;
                break;
        }

        this.SetupCommandBuffer();
    }

    public void OnDisable()
    {
        this.RemoveCommandBuffer();
    }

    public void Update()
    {
        this.WorldToView = mCamera.worldToCameraMatrix;
        this.ViewToWorld = this.WorldToView.inverse;
        this.ViewToClip = mCamera.projectionMatrix;
        this.ClipToView = this.ViewToClip.inverse;

        this.mMaterial.SetVector("_PointLightPenumbra", new Vector3(16.0f, 16.0f, 0.0f));
        this.mMaterial.SetVector("_SpotLightPenumbra", new Vector3(16.0f, 16.0f, 0.0f));
        this.mMaterial.SetVector("_DirLightPenumbra", new Vector3(16.0f, 16.0f, 0.0f));

        Shader.SetGlobalMatrix("_WorldToViewMatrix", this.WorldToView);
        Shader.SetGlobalMatrix("_ViewToWorldMatrix", this.ViewToWorld);
        Shader.SetGlobalMatrix("_ViewToClipMatrix", this.ViewToClip);
        Shader.SetGlobalMatrix("_ClipToViewMatrix", this.ClipToView);

        if (this.mLight)
        {
            if (this.mLight.type == LightType.Spot)
            {
                UpdateProjectionMatrix();
            }
        }
    }

    private void UpdateProjectionMatrix()
    {
        Matrix4x4 LightClip = Matrix4x4.TRS(new Vector3(0.5f, 0.5f, 0.5f), Quaternion.identity, new Vector3(0.5f, 0.5f, 0.5f));
        Matrix4x4 LightView = Matrix4x4.TRS(this.mLight.transform.position, this.mLight.transform.rotation, Vector3.one).inverse;
        Matrix4x4 LightProj = Matrix4x4.Perspective(this.mLight.spotAngle, 1, this.mLight.shadowNearPlane, this.mLight.range);

        float near = this.mLight.shadowNearPlane;
        float far = this.mLight.range;

        Vector4 Params = new Vector4(
            1.0f - far / near,
            far / near,
            1.0f / far - 1.0f / near,
            1.0f / near
        );

        Matrix4x4 m = LightClip * LightProj;

        m[0, 2] *= -1;
        m[1, 2] *= -1;
        m[2, 2] *= -1;
        m[3, 2] *= -1;

        if (this.mMaterial)
        {
            this.mMaterial.SetVector("_ShadowDepthParams", Params);
            this.mMaterial.SetMatrix("_ShadowProjMatrix", m * LightView);
        }
    }

    private void SetupCommandBuffer()
    {
        RenderTargetIdentifier source = BuiltinRenderTextureType.CurrentActive;

        int flipSM = Shader.PropertyToID("_TemporaryFlipShadowMap");
        int flopSM = Shader.PropertyToID("_TemporaryFlopShadowMap");

        int target = Shader.PropertyToID("_ScreenSpaceShadowMap");

        this.mBuffer = new CommandBuffer() { name = "HSSSS.ScreenSpaceShadow" };
        this.mBuffer.SetShadowSamplingMode(source, ShadowSamplingMode.RawDepth);
        this.mBuffer.GetTemporaryRT(target, -1, -1, 0, FilterMode.Point, RenderTextureFormat.RGHalf, RenderTextureReadWrite.Linear);
        this.mBuffer.GetTemporaryRT(flipSM, -1, -1, 0, FilterMode.Point, RenderTextureFormat.RGHalf, RenderTextureReadWrite.Linear);
        this.mBuffer.GetTemporaryRT(flopSM, -1, -1, 0, FilterMode.Point, RenderTextureFormat.RGHalf, RenderTextureReadWrite.Linear);

        this.mBuffer.Blit(source, flipSM, this.mMaterial, 7);
        //this.mBuffer.Blit(flipSM, flopSM, this.mMaterial, 3);
        //this.mBuffer.Blit(flopSM, flipSM, this.mMaterial, 4);
        this.mBuffer.Blit(flipSM, target);

        this.mBuffer.ReleaseTemporaryRT(target);
        this.mBuffer.ReleaseTemporaryRT(flipSM);
        this.mBuffer.ReleaseTemporaryRT(flopSM);
        
        if (this.lightType == 2)
        {
            int temp = Shader.PropertyToID("_CascadeShadowMap");
            this.nBuffer = new CommandBuffer() { name = "HSSSS.BlitShadowMap"};
            this.nBuffer.SetShadowSamplingMode(source, ShadowSamplingMode.RawDepth);
            this.nBuffer.GetTemporaryRT(temp, 4096, 4096, 0, FilterMode.Point, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
            this.nBuffer.Blit(source, temp);
            this.nBuffer.ReleaseTemporaryRT(temp);

            this.mLight.AddCommandBuffer(LightEvent.AfterShadowMap, this.nBuffer);
            this.mLight.AddCommandBuffer(LightEvent.BeforeScreenspaceMask, this.mBuffer);
        }

        else
        {
            this.mLight.AddCommandBuffer(LightEvent.AfterShadowMap, this.mBuffer);
        }
    }

    private void RemoveCommandBuffer()
    {
        if (this.lightType == 2)
        {
            this.mLight.RemoveCommandBuffer(LightEvent.AfterShadowMap, this.nBuffer);
            this.mLight.RemoveCommandBuffer(LightEvent.BeforeScreenspaceMask, this.mBuffer);
        }

        else
        {
            this.mLight.RemoveCommandBuffer(LightEvent.AfterShadowMap, this.mBuffer);
        }
        
        this.mBuffer = null;
        this.mMaterial = null;
    }
}