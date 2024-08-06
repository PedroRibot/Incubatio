#pragma once

#include "SceneViewExtension.h"
#include "PostProcess/PostProcessing.h"

class SHADERMODULE_API FMyViewExtension : public FSceneViewExtensionBase {
	FRHITexture* DataTexture;
	FScreenPassRenderTarget SceneColorCopyRenderTarget;
	FScreenPassRenderTarget UVMaskRenderTarget;
	FRDGTextureRef DataTextureRDG;
	bool initialised;
public:
	FMyViewExtension(const FAutoRegister& AutoRegister, FRHITexture* Texture);
	void UpdateTexture(FRHITexture* Texture);

	//~ Begin FSceneViewExtensionBase Interface
	virtual void SetupViewFamily(FSceneViewFamily& InViewFamily) override {};
	virtual void SetupView(FSceneViewFamily& InViewFamily, FSceneView& InView) override {};
	virtual void BeginRenderViewFamily(FSceneViewFamily& InViewFamily) override {};
	virtual void PreRenderViewFamily_RenderThread(FRHICommandListImmediate& RHICmdList, FSceneViewFamily& InViewFamily) override {};
	virtual void PreRenderView_RenderThread(FRHICommandListImmediate& RHICmdList, FSceneView& InView) override {};
	virtual void PostRenderBasePass_RenderThread(FRHICommandListImmediate& RHICmdList, FSceneView& InView) override {};
	virtual void PrePostProcessPass_RenderThread(FRDGBuilder& GraphBuilder, const FSceneView& View, const FPostProcessingInputs& Inputs) override;
	//~ End FSceneViewExtensionBase Interface
};