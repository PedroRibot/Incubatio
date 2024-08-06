// MyBlueprintFunctionLibrary.cpp
#include "MyBlueprintFunctionLibrary.h"
#include "Engine/Texture.h"
#include "Engine/World.h"
#include "Engine/Engine.h"
#include "Engine/PostProcessVolume.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Kismet/GameplayStatics.h"

void UMyBlueprintFunctionLibrary::ApplyPostProcess(UTexture* Texture, UMaterialInterface* PostProcessMaterial)
{
    if (!Texture || !PostProcessMaterial)
    {
        return;
    }

    UMaterialInstanceDynamic* MaterialInstance = UMaterialInstanceDynamic::Create(PostProcessMaterial, nullptr);
    if (!MaterialInstance)
    {
        return;
    }

    MaterialInstance->SetTextureParameterValue(FName("MyTexture"), Texture);

    // Find the PostProcessVolume in the level
    TArray<AActor*> FoundActors;
    UGameplayStatics::GetAllActorsOfClass(GEngine->GetWorldContexts()[0].World(), APostProcessVolume::StaticClass(), FoundActors);

    for (AActor* Actor : FoundActors)
    {
        APostProcessVolume* PostProcessVolume = Cast<APostProcessVolume>(Actor);
        if (PostProcessVolume)
        {
            PostProcessVolume->Settings.WeightedBlendables.Array.Add(FWeightedBlendable(1.0f, MaterialInstance));
            break;
        }
    }
}