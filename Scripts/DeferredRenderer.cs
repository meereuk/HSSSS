using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class DeferredRenderer : MonoBehaviour
{
    public enum LUTProfile
    {
        penner = 0,
        nvidia1 = 1,
        nvidia2 = 2
    };

    public struct SkinSettings
    {
        public bool sssEnabled;
        public bool transEnabled;

        public LUTProfile lutProfile;

        public float sssWeight;

        public float skinLutBias;
        public float skinLutScale;
        public float shadowLutBias;
        public float shadowLutScale;

        public float normalBlurWeight;
        public float normalBlurRadius;
        public float normalBlurDepthRange;

        public int normalBlurIter;

        public Vector3 colorBleedWeights;
        public Vector3 transAbsorption;

        public float transWeight;
        public float transShadowWeight;
        public float transDistortion;
        public float transFalloff;
    }

    private const float c_blurDepthRangeMultiplier = 25.0f;
    private const string c_copyTransmissionBufferName = "AlloyCopyTransmission";
    private const string c_normalBufferName = "AlloyRenderBlurredNormals";
    private const string c_releaseDeferredBuffer = "AlloyReleaseDeferredPlusBuffers";

    public Shader DeferredTransmissionBlit;
    public Shader DeferredBlurredNormals;

    private Material m_deferredTransmissionBlitMaterial;
    private Material m_deferredBlurredNormalsMaterial;

    private CommandBuffer m_copyTransmission;
    private CommandBuffer m_renderBlurredNormals;
    private CommandBuffer m_releaseDeferredPlus;

    private Material m_sceneViewBlurredNormalsMaterial;
    private Camera m_sceneCamera;
    private CommandBuffer m_sceneViewBlurredNormals;

    public Texture2D skinLut;
    public Texture2D shadowLut;
    public Texture2D skinJitter;

    private Camera m_camera;

    private SkinSettings skinSettings = new SkinSettings()
    {
        sssEnabled = true,
        transEnabled = true,

        lutProfile = LUTProfile.nvidia1,

        sssWeight = 1.0f,

        skinLutBias = 0.0f,
        skinLutScale = 1.0f,

        shadowLutBias = 0.0f,
        shadowLutScale = 0.5f,

        normalBlurWeight = 1.0f,
        normalBlurRadius = 0.2f,
        normalBlurDepthRange = 2.0f,

        normalBlurIter = 4,

        colorBleedWeights = new Vector3(0.40f, 0.15f, 0.20f),
        transAbsorption = new Vector3(-8.00f, -48.0f, -64.0f),

        transWeight = 1.0f,
        transShadowWeight = 0.8f,
        transDistortion = 0.0f,
        transFalloff = 4.0f
    };

    private bool transmissionEnabled;
    private bool scatteringEnabled;

    public void Refresh()
    {
        bool scatteringEnabled = skinSettings.sssEnabled;
        bool transmissionEnabled = skinSettings.transEnabled || skinSettings.sssEnabled;

        if (this.transmissionEnabled != transmissionEnabled
            || this.scatteringEnabled != scatteringEnabled)
        {
            this.scatteringEnabled = scatteringEnabled;
            this.transmissionEnabled = transmissionEnabled;

            DestroyCommandBuffers();
            InitializeBuffers();
        }

        RefreshProperties();
    }

    private void Awake()
    {
        this.m_camera = GetComponent<Camera>();
    }

    private void Reset()
    {
        InitializeBuffers();
    }

    private void OnEnable()
    {
        InitializeBuffers();
    }

    private void OnDisable()
    {
        DestroyCommandBuffers();
    }

    private void OnDestroy()
    {
        DestroyCommandBuffers();
    }

    //per camera properties
    private void RefreshProperties()
    {
        if (transmissionEnabled || scatteringEnabled)
        {
            float transmissionWeight = transmissionEnabled ? Mathf.GammaToLinearSpace(skinSettings.transWeight) : 0.0f;

            Shader.SetGlobalVector("_DeferredTransmissionParams",
                new Vector4(transmissionWeight, skinSettings.transFalloff, skinSettings.transDistortion, skinSettings.transShadowWeight));

            if (scatteringEnabled)
            {
                RefreshBlurredNormalProperties(m_camera, m_deferredBlurredNormalsMaterial);

                Shader.SetGlobalTexture("_DeferredSkinLut", skinLut);
                Shader.SetGlobalTexture("_DeferredShadowLut", shadowLut);

                Shader.EnableKeyword("_PCF_TAPS_64");
                Shader.EnableKeyword("_DIR_PCF_ON");
                Shader.EnableKeyword("_PCSS_ON");
                Shader.EnableKeyword("_FACEWORKS_TYPE1");
                Shader.SetGlobalVector("_DirLightPenumbra", new Vector3(1.0f, 1.0f, 1.0f));
                Shader.SetGlobalVector("_SpotLightPenumbra", new Vector3(1.0f, 1.0f, 1.0f));
                Shader.SetGlobalVector("_PointLightPenumbra", new Vector3(0.0f, 0.0f, 50.0f));

                Shader.SetGlobalVector("_DeferredSkinParams",
                    new Vector4(skinSettings.sssWeight, skinSettings.skinLutBias, skinSettings.skinLutScale, skinSettings.normalBlurWeight));
                Shader.SetGlobalVector("_DeferredSkinColorBleedAoWeights", skinSettings.colorBleedWeights);
                Shader.SetGlobalVector("_DeferredSkinTransmissionAbsorption", skinSettings.transAbsorption);

                Shader.SetGlobalVector("_DeferredShadowParams", new Vector2(skinSettings.shadowLutBias, skinSettings.shadowLutScale));
            }
        }
    }

    private void RefreshBlurredNormalProperties(Camera camera, Material blurMaterial)
    {
        if (blurMaterial == null)
        {
            return;
        }

        float distanceToProjectionWindow = 1.0f / Mathf.Tan(0.5f * Mathf.Deg2Rad * camera.fieldOfView);

        float blurWidth = skinSettings.normalBlurRadius * distanceToProjectionWindow;
        float blurDepthRange = skinSettings.normalBlurDepthRange * distanceToProjectionWindow * c_blurDepthRangeMultiplier;

        blurMaterial.SetTexture("_SkinJitter", skinJitter);
        blurMaterial.SetVector("_DeferredBlurredNormalsParams", new Vector2(blurWidth, blurDepthRange));
    }

    private void InitializeBuffers()
    {
        scatteringEnabled = skinSettings.sssEnabled;
        transmissionEnabled = skinSettings.transEnabled || scatteringEnabled;

#if UNITY_EDITOR
        EditorUtility.SetDirty(this);
#endif

        if ((transmissionEnabled || scatteringEnabled)
            && m_camera != null
            && DeferredTransmissionBlit != null
            && m_copyTransmission == null
            && m_releaseDeferredPlus == null)
        {
            int opacityBufferId = Shader.PropertyToID("_DeferredTransmissionBuffer");
            int blurredNormalsBufferIdTemp = Shader.PropertyToID("_DeferredBlurredNormalBufferTemp");
            int blurredNormalBuffer = Shader.PropertyToID("_DeferredBlurredNormalBuffer");

            m_deferredTransmissionBlitMaterial = new Material(DeferredTransmissionBlit);
            m_deferredTransmissionBlitMaterial.hideFlags = HideFlags.HideAndDontSave;

            // Copy Gbuffer emission buffer so we can get at the alpha channel for transmission.
            m_copyTransmission = new CommandBuffer();
            m_copyTransmission.name = c_copyTransmissionBufferName;
            m_copyTransmission.GetTemporaryRT(opacityBufferId, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGB32);
            m_copyTransmission.Blit(BuiltinRenderTextureType.CameraTarget, opacityBufferId, m_deferredTransmissionBlitMaterial);

            // Blurred normals for skin
            if (scatteringEnabled)
            {
                GenerateNormalBlurMaterialAndCommandBuffer(blurredNormalBuffer, blurredNormalsBufferIdTemp,
                    out m_deferredBlurredNormalsMaterial, out m_renderBlurredNormals);

#if UNITY_EDITOR
                GenerateNormalBlurMaterialAndCommandBuffer(blurredNormalBuffer, blurredNormalsBufferIdTemp,
                    out m_sceneViewBlurredNormalsMaterial, out m_sceneViewBlurredNormals);
#endif
            }

            // Cleanup resources.
            m_releaseDeferredPlus = new CommandBuffer();
            m_releaseDeferredPlus.name = c_releaseDeferredBuffer;
            m_releaseDeferredPlus.ReleaseTemporaryRT(opacityBufferId);

            if (scatteringEnabled)
            {
                m_releaseDeferredPlus.ReleaseTemporaryRT(blurredNormalsBufferIdTemp);
            }

#if UNITY_EDITOR
            SceneView.onSceneGUIDelegate += OnSceneGUIDelegate;
#endif
        }

        AddCommandBuffersToCamera(m_camera, m_renderBlurredNormals);

#if UNITY_EDITOR
        EditorUtility.SetDirty(m_camera);
#endif
    }

    private void GenerateNormalBlurMaterialAndCommandBuffer(int blurredNormalBuffer, int blurredNormalsBufferIdTemp,
        out Material blurMaterial, out CommandBuffer blurCommandBuffer)
    {
        blurMaterial = new Material(DeferredBlurredNormals);
        blurMaterial.hideFlags = HideFlags.HideAndDontSave;

        blurCommandBuffer = new CommandBuffer();
        blurCommandBuffer.name = c_normalBufferName;
        blurCommandBuffer.GetTemporaryRT(blurredNormalsBufferIdTemp, -1, -1, 0, FilterMode.Point,
            RenderTextureFormat.ARGB2101010);
        blurCommandBuffer.GetTemporaryRT(blurredNormalBuffer, -1, -1, 0, FilterMode.Point, RenderTextureFormat.ARGB2101010);

        blurCommandBuffer.Blit(BuiltinRenderTextureType.GBuffer2, blurredNormalsBufferIdTemp, blurMaterial, 0);
        blurCommandBuffer.Blit(blurredNormalsBufferIdTemp, blurredNormalBuffer, blurMaterial, 1);

        for (int i = 1; i < skinSettings.normalBlurIter; i++)
        {
            blurCommandBuffer.Blit(blurredNormalBuffer, blurredNormalsBufferIdTemp, blurMaterial, 0);
            blurCommandBuffer.Blit(blurredNormalsBufferIdTemp, blurredNormalBuffer, blurMaterial, 1);
        }
    }

    private void AddCommandBuffersToCamera(Camera setCamera, CommandBuffer normalBuffer)
    {
        //Need depth texture for depth aware upsample
        setCamera.depthTextureMode |= DepthTextureMode.Depth;

        if (m_copyTransmission != null && !HasCommandBuffer(setCamera, CameraEvent.AfterGBuffer, c_copyTransmissionBufferName))
        {
            setCamera.AddCommandBuffer(CameraEvent.AfterGBuffer, m_copyTransmission);
        }

        if (normalBuffer != null && !HasCommandBuffer(setCamera, CameraEvent.BeforeLighting, c_normalBufferName))
        {
            setCamera.AddCommandBuffer(CameraEvent.BeforeLighting, normalBuffer);
        }

        if (m_releaseDeferredPlus != null && !HasCommandBuffer(setCamera, CameraEvent.AfterLighting, c_releaseDeferredBuffer))
        {
            setCamera.AddCommandBuffer(CameraEvent.AfterLighting, m_releaseDeferredPlus);
        }

        RefreshProperties();
    }

    private static bool HasCommandBuffer(Camera setCamera, CameraEvent evt, string name)
    {
        foreach (var buf in setCamera.GetCommandBuffers(evt))
        {
            if (buf.name == name)
            {
                return true;
            }
        }

        return false;
    }

    private void RemoveCommandBuffers()
    {
        if (m_copyTransmission != null)
        {
            m_camera.RemoveCommandBuffer(CameraEvent.AfterGBuffer, m_copyTransmission);
        }

        if (m_renderBlurredNormals != null)
        {
            m_camera.RemoveCommandBuffer(CameraEvent.BeforeLighting, m_renderBlurredNormals);
        }

        if (m_releaseDeferredPlus != null)
        {
            m_camera.RemoveCommandBuffer(CameraEvent.AfterLighting, m_releaseDeferredPlus);
        }
    }

    private void DestroyCommandBuffers()
    {
        RemoveCommandBuffers();

        m_copyTransmission = null;
        m_renderBlurredNormals = null;
        m_releaseDeferredPlus = null;

#if UNITY_EDITOR
        m_sceneViewBlurredNormals = null;
        SceneView.onSceneGUIDelegate -= OnSceneGUIDelegate;
#endif

        if (m_deferredTransmissionBlitMaterial != null)
        {
            DestroyImmediate(m_deferredTransmissionBlitMaterial);
            m_deferredTransmissionBlitMaterial = null;
        }

        if (m_deferredBlurredNormalsMaterial != null)
        {
            DestroyImmediate(m_deferredBlurredNormalsMaterial);
            m_deferredBlurredNormalsMaterial = null;
        }

#if UNITY_EDITOR
        if (m_sceneViewBlurredNormalsMaterial != null)
        {
            DestroyImmediate(m_sceneViewBlurredNormalsMaterial);
            m_sceneViewBlurredNormalsMaterial = null;
        }
#endif
    }

#if UNITY_EDITOR
    private void OnSceneGUIDelegate(SceneView sceneView)
    {
        m_sceneCamera = sceneView.camera;
        AddCommandBuffersToCamera(m_sceneCamera, m_sceneViewBlurredNormals);
        RefreshBlurredNormalProperties(m_sceneCamera, m_sceneViewBlurredNormalsMaterial);
    }
#endif
}