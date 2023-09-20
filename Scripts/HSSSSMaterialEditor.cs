using System;
using System.Reflection.Emit;
using UnityEngine;

namespace UnityEditor
{
	public class HSSSSMaterialEditor : ShaderGUI
	{
		private Material mMaterial;
		private MaterialEditor mEditor;
		private MaterialProperty[] mProps;

		private bool showDiffuse;
		private bool showSpecular;
		private bool showOcclusion;
		private bool showNormal;
		private bool showTessellation;

		#region Properties
        #endregion

        public override void OnGUI (MaterialEditor editor, MaterialProperty[] props)
		{
			this.mMaterial = editor.target as Material;
			this.mEditor = editor;
			this.mProps = props;

			showDiffuse = EditorGUILayout.Foldout(showDiffuse, "Diffuse Properties");

            Separator();

            if (showDiffuse)
			{
				this.DiffuseInspector();
			}

			showSpecular = EditorGUILayout.Foldout(showSpecular, "Specular Properties");

            Separator();

			if (showSpecular)
			{
				this.SpecularInspector();
			}

            showOcclusion = EditorGUILayout.Foldout(showOcclusion, "Occlusion Properties");

            Separator();

			if (showOcclusion)
			{
				this.OcclusionInspector();
			}

            showNormal = EditorGUILayout.Foldout(showNormal, "Normal Properties");

            Separator();

            if (showNormal)
            {
				this.NormalInspector();
            }

            showTessellation = EditorGUILayout.Foldout(showTessellation, "Tessellation Properties");

            Separator();
        }

		private void DiffuseInspector()
		{
			PropertyInspector("_MainTex", "Main Texture");
			PropertyInspector("_Color", "Main Color");

			PropertyInspector("_ColorMask", "Color Mask");
			PropertyInspector("_Color_3", "Secondary Color");

			PropertyInspector("_DetailAlbedoMap", "Detail Albedo");

			PropertyInspector("_EmissionMap", "Emission Texture");
			PropertyInspector("_EmissionColor", "Emission Color");

			Separator();
        }

		private void SpecularInspector()
		{
			PropertyInspector("_SpecGlossMap", "Specular/Glossiness Texture");
			PropertyInspector("_SpecColor", "Specular Color");
			PropertyInspector("_Metallic", "Metallic");
			PropertyInspector("_Smoothness", "Smoothness");

			Separator();
		}

		private void OcclusionInspector()
		{
			PropertyInspector("_OcclusionMap", "Occlusion Texture");
			PropertyInspector("_OcclusionStrength", "Occlusion Strength");

            Separator();
        }

		private void NormalInspector()
		{
			PropertyInspector("_BumpMap", "Bump Texture");
			PropertyInspector("_BumpScale", "Bump Scale");

			PropertyInspector("_BlendNormalMap", "Blendnormal Texture");
			PropertyInspector("_BlendNormalMapScale", "Blendnormal Scale");

			PropertyInspector("_DetailNormalMap", "Detailnormal Texture");
			PropertyInspector("_DetailNormalMapScale", "Detailnormal Scale");
		}

		private void PropertyInspector(string name, string label)
		{
			if (this.mMaterial.HasProperty(name))
			{
				this.mEditor.ShaderProperty(FindProperty(name, this.mProps), label);
            }
		}

		private static void Separator(int height = 1)
		{
			Rect rect = EditorGUILayout.GetControlRect(false, height);
			EditorGUI.DrawRect(rect, new Color (0.0f, 0.0f, 0.0f, 1.0f));
		}

		/*
		private static GUIContent label = new GUIContent("", "");

		private Material mMaterial;
		private MaterialEditor mEditor;
		private MaterialProperty[] mProps;

		private bool showAlbedoField = true;
		private bool showSpecularField = true;

		public override void OnGUI (MaterialEditor editor, MaterialProperty[] props)
		{
			this.mMaterial = editor.target as Material;
			this.mEditor = editor;
			this.mProps = props;

			showAlbedoField = EditorGUILayout.Foldout(showAlbedoField, "Diffuse Properties");

			if (showAlbedoField)
			{
				this.DiffuseProps();
			}

			showSpecularField = EditorGUILayout.Foldout(showSpecularField, "Specular & Occlusion Properties");

			if (showSpecularField)
			{
				this.SpecularProps();
			}
		}

		private void DiffuseProps()
		{
			// albedo
			GUILayout.Label("Albedo", EditorStyles.boldLabel);

			this.albedoMap = FindProperty("_MainTex", this.mProps);
			this.albedoColor = FindProperty("_Color", this.mProps);

			this.mEditor.TexturePropertySingleLine(label, this.albedoMap, this.albedoColor);
			this.mEditor.TextureScaleOffsetProperty(this.albedoMap);

			// secondary albedo
			GUILayout.Label("Color Mask", EditorStyles.boldLabel);

			this.mEditor.ShaderProperty(FindProperty("_COLORMASK", this.mProps), "Toggle");

			if (this.mMaterial.IsKeywordEnabled("_COLORMASK_ON"))
			{
				this.colorMask = FindProperty("_ColorMask", this.mProps);
				this.secondColor = FindProperty("_Color_3", this.mProps);
				this.mEditor.TexturePropertySingleLine(label, this.colorMask, this.secondColor);
				this.mEditor.TextureScaleOffsetProperty(this.colorMask);
			}

			// detail albedo
			GUILayout.Label("Detail Albedo", EditorStyles.boldLabel);
			this.mEditor.ShaderProperty(FindProperty("_DETAILALBEDO", this.mProps), "Toggle");

			if (this.mMaterial.IsKeywordEnabled("_DETAILALBEDO_ON"))
			{
				this.detailAlbedo = FindProperty("_DetailAlbedoMap", this.mProps);
				this.mEditor.TexturePropertySingleLine(label, this.detailAlbedo);
				this.mEditor.TextureScaleOffsetProperty(this.detailAlbedo);
			}
		}

		private void SpecularProps()
		{
			GUILayout.Label("SpecGloss Map", EditorStyles.boldLabel);
			this.specularMap = FindProperty("_SpecGlossMap", this.mProps);
			this.specularColor = FindProperty("_SpecColor", this.mProps);
			this.mEditor.TexturePropertySingleLine(label, this.specularMap, this.specularColor);
			this.mEditor.TextureScaleOffsetProperty(this.specularMap);

			this.mEditor.ShaderProperty(FindProperty("_Metallic", this.mProps), "Metallic");
			this.mEditor.ShaderProperty(FindProperty("_Smoothness", this.mProps), "Smoothness");

			GUILayout.Label("Occlusion Map", EditorStyles.boldLabel);
			this.occlusionMap = FindProperty("_OcclusionMap", this.mProps);
			this.occluionStrength = FindProperty("_OcclusionStrength", this.mProps);
			this.mEditor.TexturePropertySingleLine(label, this.occlusionMap, this.occluionStrength);
			this.mEditor.TextureScaleOffsetProperty(this.occlusionMap);
		}
		*/
	}
}