// MyCustomModule/Private/MyCustomModule.cpp

#include "ShaderModule.h"

void FShaderModule::StartupModule() {
	FString BaseDir = FPaths::Combine(FPaths::GameSourceDir(), TEXT("ShaderModule"));
	FString ModuleShaderDir = FPaths::Combine(BaseDir, TEXT("Shaders"));
	AddShaderSourceDirectoryMapping(TEXT("/ShaderModule"), ModuleShaderDir);
	UE_LOG(LogTemp, Warning, TEXT("--ShaderModuleLoaded--"));
}

IMPLEMENT_MODULE(FShaderModule, ShaderModule)