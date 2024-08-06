#pragma once

#include "CoreMinimal.h"
#include "GenericPlatform/GenericPlatformMisc.h"
#include "Kismet/BlueprintAsyncActionBase.h"
#include "Engine/TextureRenderTarget2D.h"
#include "Materials/MaterialRenderProxy.h"

#include "SimpleComputeShader.generated.h"

struct MYCOMPUTESHADERS_API FSimpleComputeShaderDispatchParams
{
	int X;
	int Y;
	int Z;

	
	FRenderTarget* RenderTarget;
	FRenderTarget* DataTexture;
	

	FSimpleComputeShaderDispatchParams(int x, int y, int z)
		: X(x)
		, Y(y)
		, Z(z)
	{
	}
};

// This is a public interface that we define so outside code can invoke our compute shader.
class MYCOMPUTESHADERS_API FSimpleComputeShaderInterface {
public:

	// Executes this shader on the render thread
	static void DispatchRenderThread(
		FRHICommandListImmediate& RHICmdList,
		FSimpleComputeShaderDispatchParams Params
	);

	// Executes this shader on the render thread from the game thread via EnqueueRenderThreadCommand
	static void DispatchGameThread(
		FSimpleComputeShaderDispatchParams Params
	)
	{
		ENQUEUE_RENDER_COMMAND(SceneDrawCompletion)(
		[Params](FRHICommandListImmediate& RHICmdList)
		{
			DispatchRenderThread(RHICmdList, Params);
		});
	}

	// Dispatches this shader. Can be called from any thread
	static void Dispatch(
		FSimpleComputeShaderDispatchParams Params
	)
	{
		if (IsInRenderingThread()) {
			DispatchRenderThread(GetImmediateCommandList_ForRenderCommand(), Params);
		}else{
			DispatchGameThread(Params);
		}
	}
};

// This is a static blueprint library that can be used to invoke our compute shader from blueprints.
UCLASS()
class MYCOMPUTESHADERS_API USimpleComputeShaderLibrary : public UObject
{
	GENERATED_BODY()
	
public:
	UFUNCTION(BlueprintCallable)
	static void ExecuteRTComputeShader(UTextureRenderTarget2D* RT,UTextureRenderTarget2D* DataTexture)
	{
		// Create a dispatch parameters struct and fill it the input array with our args
		FSimpleComputeShaderDispatchParams Params(RT->SizeX, RT->SizeY, 1);
		Params.RenderTarget = RT->GameThread_GetRenderTargetResource();
		Params.DataTexture = DataTexture->GameThread_GetRenderTargetResource();
		FSimpleComputeShaderInterface::Dispatch(Params);

	}
};
