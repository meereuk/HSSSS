using System;
using UnityEngine;

namespace UnityEditor
{
	public class HSSSSMaterialEditor : ShaderGUI
	{
		private static GUIContent label = new GUIContent("", "");

		private Material mMaterial;
		private MaterialEditor mEditor;
		private MaterialProperty[] mProps;

		private MaterialProperty albedoMap = null;
		private MaterialProperty albedoColor = null;
		private MaterialProperty colorMask = null;
		private MaterialProperty secondColor = null;
		private MaterialProperty detailAlbedo = null;

		private MaterialProperty specularMap = null;
		private MaterialProperty specularColor = null;
		private MaterialProperty metallic = null;
		private MaterialProperty smoothness = null;

		private MaterialProperty occlusionMap = null;
		private MaterialProperty occluionStrength = null;

		private MaterialProperty bumpMap = null;
		private MaterialProperty bumpScale = null;

		private MaterialProperty blendNormalMap = null;
		private MaterialProperty blendNormalMapScale = null;

		private MaterialProperty detailNormalMap = null;
		private MaterialProperty detailNormalMapScale = null;

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
	}
}