#pragma once

#include "CoreMinimal.h"
#include "MyComputeShaders/Public/MyComputeShaders.h"
#include "MeshPassProcessor.h"
#include "RHICommandList.h"
#include "RenderGraphBuilder.h"
#include "RenderTargetPool.h"
#include "MeshMaterialShader.h"
#include "ShaderParameterUtils.h"
#include "RHIStaticStates.h"
#include "Shader.h"
#include "RHI.h"
#include "GlobalShader.h"
#include "RenderGraphUtils.h"
#include "ShaderParameterStruct.h"
#include "UniformBuffer.h"
#include "RHICommandList.h"
#include "ShaderCompilerCore.h"
#include "EngineDefines.h"
#include "RendererInterface.h"
#include "RenderResource.h"
#include "RenderGraphResources.h"

#include "RenderGraphResources.h"
#include "Runtime/Engine/Classes/Engine/TextureRenderTarget2D.h"

#define NUM_THREADS_SimpleComputeShader_X 32
#define NUM_THREADS_SimpleComputeShader_Y 32
#define NUM_THREADS_SimpleComputeShader_Z 1