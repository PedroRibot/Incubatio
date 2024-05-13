// Fill out your copyright notice in the Description page of Project Settings.


#include "CPP_OSC_to_Material.h"

// Sets default values
ACPP_OSC_to_Material::ACPP_OSC_to_Material()
{
 	// Set this actor to call Tick() every frame.  You can turn this off to improve performance if you don't need it.
	PrimaryActorTick.bCanEverTick = true;

}

// Called when the game starts or when spawned
void ACPP_OSC_to_Material::BeginPlay()
{
	Super::BeginPlay();
	
}

// Called every frame
void ACPP_OSC_to_Material::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);

}

UTexture2D* ACPP_OSC_to_Material::FillTextureWithMatrixData(const TArray<FMatrix>& Matrices)
{
    if (Matrices.Num() == 0)
    {
        return nullptr; // Return null if there are no matrices to process.
    }

    // Texture size calculations
    int32 TextureWidth = 4; // One row of a matrix fits into one pixel .
    int32 TextureHeight = Matrices.Num();

    // Create a new texture
        UTexture2D* Texture = UTexture2D::CreateTransient(TextureWidth, TextureHeight, PF_A32B32G32R32F);
    #if WITH_EDITORONLY_DATA
        Texture->CompressionSettings = TextureCompressionSettings::TC_VectorDisplacementmap;
    #endif
        Texture->SRGB = 0;
        Texture->AddToRoot(); // Prevents texture from being garbage collected
        Texture->UpdateResource();

    // Lock the texture for editing
    FTexture2DMipMap& MipMap = Texture->PlatformData->Mips[0];
    float* Data = static_cast<float*>(MipMap.BulkData.Lock(LOCK_READ_WRITE));

    for (int32 MatrixIndex = 0; MatrixIndex < Matrices.Num(); ++MatrixIndex)
    {
        const FMatrix& Matrix = Matrices[MatrixIndex];

        for (int32 Row = 0; Row < 4; ++Row)
        {
            // Calculate the starting index for this row in the buffer
            int32 StartIndex = (MatrixIndex * 4 + Row) * 4; // 4 floats per row, 4 rows per matrix

            Data[StartIndex + 0] = Matrix.M[Row][0]; // R channel
            Data[StartIndex + 1] = Matrix.M[Row][1]; // G channel
            Data[StartIndex + 2] = Matrix.M[Row][2]; // B channel
            Data[StartIndex + 3] = Matrix.M[Row][3]; // A channel
        }
    }

    // Unlock and update the texture
    MipMap.BulkData.Unlock();
    Texture->UpdateResource();

    return Texture; // Return the newly created and filled texture.
}

TArray<FMatrix> ACPP_OSC_to_Material::CreateTransformationMatrices(const TArray<FVector>& Positions, const TArray<FVector4>& Rotations)
{
    // Ensure the input arrays are of the same size
    if (Positions.Num() != Rotations.Num())
    {
        UE_LOG(LogTemp, Warning, TEXT("Positions and Rotations arrays do not match in size."));
        return TArray<FMatrix>(); // Return an empty array if sizes don't match
    }

    TArray<FMatrix> TransformationMatrices;

    for (int32 Index = 0; Index < Positions.Num(); ++Index)
    {
        // Convert FVector4 rotation to FQuat
        const FVector4& Rot = Rotations[Index];
        FQuat QuatRotation(Rot.X, Rot.Y, Rot.Z, Rot.W);

        // Combine position and rotation into an FTransform. Assume a scale of (1, 1, 1).
        FTransform Transform(QuatRotation.GetNormalized(), Positions[Index], FVector(1.0f, 1.0f, 1.0f));

        // Add the transform to the output array
        TransformationMatrices.Add(Transform.ToMatrixWithScale());
    }

    return TransformationMatrices;
}

FVector4 ACPP_OSC_to_Material::GetColumnFromMatrix(const FMatrix& Matrix, int32 ColumnIndex)
{
  // I CHANGED TO COLUMN FOR DEBUG POURPOSES
    if (ColumnIndex < 0 || ColumnIndex > 3)
    {
        UE_LOG(LogTemp, Warning, TEXT("Column out of bounds"));
        return FVector4(0,0,0,0);
    }
    //This is Column major
    return FVector4(Matrix.M[0][ColumnIndex], Matrix.M[1][ColumnIndex], Matrix.M[2][ColumnIndex], Matrix.M[3][ColumnIndex]);

    //This is Row major
    //return FVector4(Matrix.M[RowIndex][0], Matrix.M[RowIndex][1], Matrix.M[RowIndex][2], Matrix.M[RowIndex][3]);
}

FMatrix ACPP_OSC_to_Material::CreateMatrixFromPositionRotation(const FVector& Position, const FQuat& Rotation) 
{
    

    // Create a transformation matrix using FTransform, which handles position, rotation, and scale.
    FTransform Transform(Rotation, Position, FVector(1.0f, 1.0f, 1.0f)); // Scale set to 1

    //FMatrix Matrix = FQuatRotationTranslationMatrix(Rotation, Position);

    // Convert the FTransform to an FMatrix and return
    return Transform.ToMatrixWithScale().GetTransposed();

    //return Matrix;
}

FQuat ACPP_OSC_to_Material::AdaptRotations(const FQuat& originalRotation, int insideCount, float x, float y, float z, int bone)
{
    FQuat rotationChange = FQuat(FRotator(0, 0, 0));

    //// PELVIS
    //switch (insideCount)
    //{
    //case 0:
    //case 9:
    //case 10:
    //case 11:
    //case 12:
    //    rotationChange = FQuat(FRotator(90, 0, 0));
    //    break;

    //    // LEFT ARM
    //case 17:
    //case 18:
    //case 19:
    //case 20:
    //    rotationChange = FQuat(FRotator(90, 0, 90));
    //    break;

    //    // RIGHT ARM
    //case 13:
    //case 14:
    //case 15:
    //case 16:
    //    rotationChange = FQuat(FRotator(90, 0, -90));
    //    break;

    //    // NECK
    //case 21:
    //case 22:
    //    rotationChange = FQuat(FRotator(90, 0, 0));
    //    break;

    //    // LEFT UPPER LEG 
    //case 1:
    //case 2:
    //    rotationChange = FQuat(FRotator(-90, 180, 0));
    //    break;
    //case 3:
    //case 4:
    //    rotationChange = FQuat(FRotator(-180, 180, 0));
    //    break;

    //    // RIGHT UPPER LEG
    //case 5:
    //case 6:
    //    rotationChange = FQuat(FRotator(-90, 180, 0));
    //    break;
    //case 7:
    //case 8:
    //    rotationChange = FQuat(FRotator(-180, 180, 0));
    //    break;

    //default:
    //    break;
    //}

    if (insideCount == bone) {
        rotationChange = FQuat(FRotator(x, y, z));
    }

   

    return originalRotation * rotationChange;
}