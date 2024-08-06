#pragma once

#include "CoreMinimal.h"
#include "GenericPlatform/GenericPlatformMisc.h"
#include "Kismet/BlueprintAsyncActionBase.h"
#include "Engine/TextureRenderTarget2D.h"
#include "Materials/MaterialRenderProxy.h"

#include "PIExampleComputeShader.generated.h"

struct MYCOMPUTESHADERS_API FPIExampleComputeShaderDispatchParams
{
	int X;
	int Y;
	int Z;

	
	float Seed;
	
	

	FPIExampleComputeShaderDispatchParams(int x, int y, int z)
		: X(x)
		, Y(y)
		, Z(z)
	{
	}
};

// This is a public interface that we define so outside code can invoke our compute shader.
class MYCOMPUTESHADERS_API FPIExampleComputeShaderInterface {
public:
	// Executes this shader on the render thread
	static void DispatchRenderThread(
		FRHICommandListImmediate& RHICmdList,
		FPIExampleComputeShaderDispatchParams Params,
		TFunction<void(int TotalInCircle)> AsyncCallback
	);

	// Executes this shader on the render thread from the game thread via EnqueueRenderThreadCommand
	static void DispatchGameThread(
		FPIExampleComputeShaderDispatchParams Params,
		TFunction<void(int OutputVal)> AsyncCallback
	)
	{
		ENQUEUE_RENDER_COMMAND(SceneDrawCompletion)(
		[Params, AsyncCallback](FRHICommandListImmediate& RHICmdList)
		{
			DispatchRenderThread(RHICmdList, Params, AsyncCallback);
		});
	}

	// Dispatches this shader. Can be called from any thread
	static void Dispatch(
		FPIExampleComputeShaderDispatchParams Params,
		TFunction<void(int TotalInCircle)> AsyncCallback
	)
	{
		if (IsInRenderingThread()) {
			DispatchRenderThread(GetImmediateCommandList_ForRenderCommand(), Params, AsyncCallback);
		}else{
			DispatchGameThread(Params, AsyncCallback);
		}
	}
};



DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnPIExampleComputeShaderLibrary_AsyncExecutionCompleted, const double, Value);


UCLASS() // Change the _API to match your project
class MYCOMPUTESHADERS_API UPIExampleComputeShaderLibrary_AsyncExecution : public UBlueprintAsyncActionBase
{
	GENERATED_BODY()

public:
	
	// Execute the actual load
	virtual void Activate() override {
		// Create a dispatch parameters struct and set our desired seed
		FPIExampleComputeShaderDispatchParams Params(TotalSamples, 1, 1);
		Params.Seed = Seed;

		// Dispatch the compute shader and wait until it completes
		FPIExampleComputeShaderInterface::Dispatch(Params, [this](int TotalInCircle) {
			// TotalInCircle is set to the result of the compute shader
			// Divide by the total number of samples to get the ratio of samples in the circle
			// We're multiplying by 4 because the simulation is done in quarter-circles
			double FinalPI = ((double) TotalInCircle / (double) TotalSamples);

			Completed.Broadcast(FinalPI);
		});
	}
	
	UFUNCTION(BlueprintCallable, meta = (BlueprintInternalUseOnly = "true", Category = "ComputeShader", WorldContext = "WorldContextObject"))
	static UPIExampleComputeShaderLibrary_AsyncExecution* ExecutePIComputeShader(UObject* WorldContextObject, int TotalSamples, float Seed) {
		UPIExampleComputeShaderLibrary_AsyncExecution* Action = NewObject<UPIExampleComputeShaderLibrary_AsyncExecution>();
		Action->TotalSamples = TotalSamples;
		Action->Seed = Seed;
		Action->RegisterWithGameInstance(WorldContextObject);

		return Action;
	}
	

	UPROPERTY(BlueprintAssignable)
	FOnPIExampleComputeShaderLibrary_AsyncExecutionCompleted Completed;

	
	float Seed;
	int TotalSamples;
	
};