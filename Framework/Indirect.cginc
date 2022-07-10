// Alloy Physical Shader Framework
// Copyright 2013-2016 RUST LLC.
// http://www.alloy.rustltd.com/

/////////////////////////////////////////////////////////////////////////////////
/// @file Indirect.cginc
/// @brief AIndirect structure, and related methods.
/////////////////////////////////////////////////////////////////////////////////

#ifndef A_FRAMEWORK_INDIRECT_CGINC
#define A_FRAMEWORK_INDIRECT_CGINC

#include "UnityLightingCommon.cginc"

// Use Unity's struct directly to avoid copying since the fields are the same.
#define AIndirect UnityIndirect

/// Constructor. 
/// @return Structure initialized with sane default values.
AIndirect aCreateIndirect() {
    AIndirect i;

    UNITY_INITIALIZE_OUTPUT(AIndirect, i);
    i.diffuse = 0.0h;
    i.specular = 0.0h;

    return i;
}

#endif // A_FRAMEWORK_INDIRECT_CGINC
