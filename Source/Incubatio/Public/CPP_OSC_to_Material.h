// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Engine/Texture2D.h"
#include "Math/Vector.h"
#include "Math/Quat.h"
#include "Math/Matrix.h"
#include "CPP_OSC_to_Material.generated.h"

UCLASS()
class INCUBATIO_API ACPP_OSC_to_Material : public AActor
{
	GENERATED_BODY()
	
public:	
	// Sets default values for this actor's properties
	ACPP_OSC_to_Material();

protected:
	// Called when the game starts or when spawned
	virtual void BeginPlay() override;

public:	
	// Called every frame
	virtual void Tick(float DeltaTime) override;
	UFUNCTION(BlueprintCallable)
		UTexture2D* FillTextureWithMatrixData(const TArray<FMatrix>& Matrices);
	UFUNCTION(BlueprintCallable)
		TArray<FMatrix> CreateTransformationMatrices(const TArray<FVector>& Positions, const TArray<FVector4>& Rotations);
	UFUNCTION(BlueprintCallable)
		FVector4 GetColumnFromMatrix(const FMatrix& Matrix, int32 ColumnIndex);
	UFUNCTION(BlueprintCallable)
		FMatrix CreateMatrixFromPositionRotation(const FVector& Position, const FQuat& Rotation);
	UFUNCTION(BlueprintCallable)
		FQuat AdaptRotations(const FQuat& originalRotation, int insideCount, float x, float y, float z, int bone);
};
