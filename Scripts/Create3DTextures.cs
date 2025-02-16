using UnityEditor;
using UnityEngine;
using System.IO;

public class Create3DTextures : MonoBehaviour
{
    private static Texture2D[] tex = new Texture2D[64];

    [MenuItem("CreateExamples/3DTexture")]
    static void CreateTexture3D()
    {
        int X = 128;
        int Y = 128;
        int Z = 64;

        Texture3D tex3d = new Texture3D(X, Y, Z, TextureFormat.RGB24, false);
        Color[] colors = new Color[X * Y * Z];

        for (int z = 0; z < Z; z ++)
        {
            string filePath = "Assets/HSSSS/Resources/Textures/Jitter/STBN/RGB/stbn_" + z + ".png";

            if (!File.Exists(filePath))
            {
                Debug.LogError("No such file: " + filePath);
                continue;
            }
            
            byte[] imgData = File.ReadAllBytes(filePath);
            tex[z] = new Texture2D(X, Y, TextureFormat.RGB24, false, true);
            tex[z].LoadImage(imgData);

            Color[] slicePixels = tex[z].GetPixels();

            for (int y = 0; y < Y; y ++)
            {
                for (int x = 0; x < X; x ++)
                {
                    int index2D = x + y * X;
                    int index3D = x + y * X + z * X * Y;
                    colors[index3D] = slicePixels[index2D];
                }
            }
        }

        tex3d.SetPixels(colors);
        tex3d.Apply();
        AssetDatabase.CreateAsset(tex3d, "Assets/Example3DTexture.asset");
    }
}