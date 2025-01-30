#ifndef A_FRAMEWORK_DEFINITION_CGINC
#define A_FRAMEWORK_DEFINITION_CGINC

#include "Assets/HSSSS/Config.cginc"

#include "Assets/HSSSS/Framework/Surface.cginc"
#include "Assets/HSSSS/Framework/Utility.cginc"
#include "Assets/HSSSS/Framework/Vertex.cginc"

#include "Assets/HSSSS/Features/Common.cginc"
#include "Assets/HSSSS/Features/Overlay.cginc"
#include "Assets/HSSSS/Features/Dissolve.cginc"

#ifdef _MICRODETAILS_ON
    #include "Assets/HSSSS/Features/Microdetails.cginc"
#endif

#include "UnityCG.cginc"
#include "UnityStandardBRDF.cginc"
#include "UnityStandardUtils.cginc"

#endif
