using UnityEngine;
using UnityEngine.Rendering;
using System.Collections;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class ScreenSpaceBlur : MonoBehaviour {
    private Shader blurShader;
    private Material blurMaterial;
    private CommandBuffer blurBuffer;

    private Camera mainCamera;

    private void Awake()
    {
        this.Initialize();
    }

    private void OnEnable()
    {
        this.CreateCommandBuffer();
    }

    private void OnDisable()
    {
        this.DestroyCommandBuffer();
    }

    private void OnDestroy()
    {
        this.DestroyCommandBuffer();
    }

    private void Initialize()
    {
        this.mainCamera = GetComponent<Camera>();
        this.blurShader = Shader.Find("Hidden/HSSSS/BlurredNormals");
        //this.blurShader = Shader.Find("Hidden/ScreenSpaceBlur");
        this.blurMaterial = new Material(blurShader);
    }

    private void CreateCommandBuffer()
    {
        this.blurBuffer = new CommandBuffer();
        this.blurBuffer.name = "Fuck You";

        RenderTargetIdentifier renderTarget = BuiltinRenderTextureType.CurrentActive;

        int renderRT = Shader.PropertyToID("_DeferredRenderResult");

        this.blurBuffer.GetTemporaryRT(renderRT, -1, -1);
        this.blurBuffer.Blit(renderTarget, renderRT, this.blurMaterial, 0);
        //this.blurBuffer.Blit(renderRT, renderTarget);
        this.mainCamera.AddCommandBuffer(CameraEvent.AfterLighting, this.blurBuffer);
    }
    
    private void DestroyCommandBuffer()
    {
        this.mainCamera.RemoveCommandBuffer(CameraEvent.AfterLighting, this.blurBuffer);
    }
}
