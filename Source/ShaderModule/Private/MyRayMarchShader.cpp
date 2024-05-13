#include "MyRayMarchShader.h"

IMPLEMENT_SHADER_TYPE(, FCombineShaderPS, TEXT("/ShaderModule/MyRayMarchShader.usf"), TEXT("CombineMainPS"), SF_Pixel);
IMPLEMENT_SHADER_TYPE(, FUVMaskShaderPS, TEXT("/ShaderModule/MyRayMarchShader.usf"), TEXT("UVMaskMainPS"), SF_Pixel);