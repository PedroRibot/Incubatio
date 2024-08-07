// Fill out your copyright notice in the Description page of Project Settings.


#include "CPP_OSC_to_Material.h"
#include "MyViewExtension.h"
#include "Camera/PlayerCameraManager.h"
#include "RenderGraphBuilder.h"
#include "Engine/TextureRenderTarget2D.h"
#include "Materials/MaterialRenderProxy.h"
#include "Runtime/Engine/Classes/Engine/TextureRenderTarget2D.h"


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

FMatrix ACPP_OSC_to_Material::CreateMatrixFromPositionRotationScale(const FVector& Position, const FQuat& Rotation, const FVector& Scale)
{
    

    // Create a transformation matrix using FTransform, which handles position, rotation, and scale.
    FTransform Transform(Rotation, Position, Scale); // Scale set to 1

    //FMatrix Matrix = FQuatRotationTranslationMatrix(Rotation, Position);

    // Convert the FTransform to an FMatrix and return
    return Transform.ToMatrixWithScale().GetTransposed();

    //return Matrix;
}

void ACPP_OSC_to_Material::CreateViewExtension(UTextureRenderTarget2D* pDataTexture) {
    //FRHITexture* TextureRHI = Texture->Resource->GetTexture2DRHI();
    //FRHITexture* TextureRHI = Texture->Resource->GetTexture2DRHI();
    //FRDGTextureRef TextureRDG = GraphBuilder.RegisterExternalTexture(CreateRenderTarget(TextureRHI, TEXT("MyTexture")));
    MyViewExtension = FSceneViewExtensions::NewExtension<FMyViewExtension>(FLinearColor::Green, pDataTexture);
}

//void ACPP_OSC_to_Material::UpdateTexturePostProcessing(UTexture2D* Texture) 
//{
//    FRHITexture* TextureRHI = Texture->Resource->GetTexture2DRHI();
//    MyViewExtension->UpdateTexture(TextureRHI);
//}

//UTexture2D* ACPP_OSC_to_Material::GetTextureFromRenderTarget(UTextureRenderTarget2D* RTarget)
//{
//    //FRenderTarget* RenderTarget = GameThread_GetRenderTargetResource();
// /*   EPixelFormat pixelFormat = RTarget->GetFormat();*/
//   
//    const ETextureSourceFormat TextureFormat = RTarget->GetTextureFormatForConversionToTexture2D();
//
//    ConvertedDataTexture2D = RTarget->ConstructTexture2D(this, "texture", EObjectFlags::RF_NoFlags, CTF_DeferCompression);
//
//    /*UE_LOG(LogTemp, Warning, TEXT("The Texture2D pointer address is: %d"), Texture2D);
//    UE_LOG(LogTemp, Warning, TEXT("The EPixelFormat is: %d"), pixelFormat);
//    UE_LOG(LogTemp, Warning, TEXT("The TextureFormat is: %d"), TextureFormat);*/
//
//    RTarget->CompressionSettings = TextureCompressionSettings::TC_VectorDisplacementmap;
//#if WITH_EDITORONLY_DATA
//    ConvertedDataTexture2D->MipGenSettings = TextureMipGenSettings::TMGS_NoMipmaps;
//#endif
//    ConvertedDataTexture2D->SRGB = 1;
//    ConvertedDataTexture2D->UpdateResource();
//
//    return ConvertedDataTexture2D;
//}

//UTexture2D* ACPP_OSC_to_Material::UpdateTextureFromRenderTarget(UTextureRenderTarget2D* RTarget)
//{
//    TArray<FColor> SurfData;
//    FRenderTarget* RenderTarget = RTarget->GameThread_GetRenderTargetResource();
//    RenderTarget->ReadPixels(SurfData);
//
//    // Lock and copies the data between the textures
//    void* TextureData = ConvertedDataTexture2D->PlatformData->Mips[0].BulkData.Lock(LOCK_READ_WRITE);
//    const int32 TextureDataSize = SurfData.Num() * 4;
//    FMemory::Memcpy(TextureData, SurfData.GetData(), TextureDataSize);
//    ConvertedDataTexture2D->PlatformData->Mips[0].BulkData.Unlock();
//    // Apply Texture changes to GPU memory
//    ConvertedDataTexture2D->UpdateResource();
//
//    return ConvertedDataTexture2D;
//}

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