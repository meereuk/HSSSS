using UnityEditor;
using UnityEngine;

public class Create3DTextures : MonoBehaviour
{
    private static Texture2D[] tex = new Texture2D[64];

    [MenuItem("CreateExamples/3DTexture")]
    static void CreateTexture3D()
    {
        Texture3D tex3d = new Texture3D(128, 128, 64, TextureFormat.Alpha8, false);

        Color[] colors = new Color[128 * 128 * 64];
        //float[] colors = new float[128 * 128 * 64];

        for (int z = 0; z < 64; z ++)
        {
            string file = "Assets/HSSSS/Resources/Textures/Jitter/STBN/Grey/stbn_" + z.ToString() + ".png";
            var img = System.IO.File.ReadAllBytes(file);
            tex[z] = new Texture2D(128, 128);
            tex[z].LoadImage(img);

            for (int y = 0; y < 128; y ++)
            {
                for (int x = 0; x < 128; x ++)
                {
                    colors[x + y * 128 + z * 128 * 128].r = 1.0f;
                }
            }
        }

        tex3d.SetPixels(colors);
        tex3d.Apply();
        AssetDatabase.CreateAsset(tex3d, "Assets/Example3DTexture.asset");
    }
}