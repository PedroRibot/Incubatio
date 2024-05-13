// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "ShaderCall.generated.h"

UCLASS()
class INCUBATIO_API AShaderCall : public AActor
{
	GENERATED_BODY()
	
	TSharedPtr<class FMyViewExtension, ESPMode::ThreadSafe> MyViewExtension;

public:	
	// Sets default values for this actor's properties
	AShaderCall();

protected:
	// Called when the game starts or when spawned
	virtual void BeginPlay() override;

public:	
	// Called every frame
	virtual void Tick(float DeltaTime) override;

};
