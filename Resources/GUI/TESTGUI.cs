using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Reflection;

public class TESTGUI : MonoBehaviour {
	[SerializeField]
	public GUISkin skin;

	private static Vector2 windowPosition = new Vector2(64.0f, 64.0f);
	private static Vector2 windowSize = new Vector2 (768.0f, 512.0f);
	private static int toolBarState = 0;
	private string[] toolBarStrings = new string[] { "Option 0", "Option 1", "Option 2", "Option 3"};

	private Rect configWindow;

	// Use this for initialization
	public void Awake()
    {
		//GUI.skin = skin;
		this.configWindow = new Rect(windowPosition, windowSize);
    }
	
	// Update is called once per frame
	public void OnGUI()
    {
		GUI.skin = skin;
		this.configWindow = GUI.Window(0, this.configWindow, this.WindowFunction, "HSSSS Configuration");
    }

	private void WindowFunction(int windowID)
	{
		GUILayout.Space(32.0f);
		GUILayout.BeginHorizontal();
		{
			GUILayout.BeginVertical(GUILayout.Width(128.0f));
			{
				GUILayout.BeginHorizontal(GUILayout.Height(128.0f));
				toolBarState = GUILayout.SelectionGrid(toolBarState, this.toolBarStrings, 1);
				GUILayout.EndHorizontal();
			}
			GUILayout.EndVertical();
			GUILayout.Space(16.0f);

			GUILayout.BeginVertical(GUILayout.ExpandWidth(true));
			GUILayout.Label("TEST Slider 1");
			GUILayout.Box("", GUILayout.Height(1));
			GUILayout.Label("TEST Slider 2");
			GUILayout.Label("TEST Slider 3");
			GUILayout.Label("TEST Slider 4");
			GUILayout.EndVertical();
		}
		GUILayout.EndHorizontal();

		GUILayout.Space(16.0f);
		//
		GUILayout.Label("TEST Slider 1");
		SliderControls(0.0f, 0.0f, 1.0f);
		//
		GUILayout.Label("TEST Slider 2");
		SliderControls(0.5f, 0.0f, 1.0f);
		//
		GUILayout.Label("TEST Slider 3");
		SliderControls(1.0f, 0.0f, 1.0f);
		//
		GUILayout.Label("TEST Slider 4");
		SliderControls(1.0f, 0.0f, 1.0f);
		//
		GUILayout.Label("TEST RGB");
		this.RGBControls(new Vector3(0.50f, 1.00f, 50.0f));
		//
		GUILayout.Label("TEST Light");
		GUILayout.BeginHorizontal(GUILayout.Height(32.0f));
		//
		GUILayout.TextField("0.00", GUILayout.Width(122.0f));
		GUILayout.Button("Directional", GUILayout.Width(122.0f));
		GUILayout.Button("Point", GUILayout.Width(122.0f));
		GUILayout.Button("Spot", GUILayout.Width(122.0f));

		GUILayout.EndHorizontal();
	}

	private float SliderControls(float sliderValue, float minValue, float maxValue)
    {
		GUILayout.BeginHorizontal(GUILayout.Height(32.0f));

		sliderValue = GUILayout.HorizontalSlider(sliderValue, minValue, maxValue);
		GUILayout.TextField(sliderValue.ToString("0.00"), GUILayout.Width(64.0f));

		GUILayout.EndHorizontal();

		return sliderValue;
    }

	private Vector3 RGBControls(Vector3 rgbValue)
	{
		GUILayout.BeginHorizontal(GUILayout.Height(32.0f));

		GUILayout.Label("Red");

		GUILayout.TextField(rgbValue.x.ToString("0.00"), GUILayout.Width(96.0f));

		GUILayout.Label("Green");

		GUILayout.TextField(rgbValue.y.ToString("0.00"), GUILayout.Width(96.0f));

		GUILayout.Label("Blue");

		GUILayout.TextField(rgbValue.z.ToString("0.00"), GUILayout.Width(96.0f));
		
		GUILayout.EndHorizontal();

		return rgbValue;
	}
}
