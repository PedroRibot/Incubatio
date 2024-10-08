// Fill out your copyright notice in the Description page of Project Settings.

using System.IO;
using UnrealBuildTool;

public class Incubatio : ModuleRules
{
	public Incubatio(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
	
		PublicDependencyModuleNames.AddRange(new string[] { "Core", "CoreUObject", "Engine", "InputCore", "Renderer", "RenderCore", "RHI", "ShaderModule" });

        string EnginePath = Path.GetFullPath(Target.RelativeEnginePath);
        PublicIncludePaths.Add(EnginePath + "Source/Runtime/Renderer/Private");
        PublicIncludePaths.AddRange(new string[] { "Incubatio/Shaders" });

        PrivateDependencyModuleNames.AddRange(new string[] {  });

		// Uncomment if you are using Slate UI
		// PrivateDependencyModuleNames.AddRange(new string[] { "Slate", "SlateCore" });
		
		// Uncomment if you are using online features
		// PrivateDependencyModuleNames.Add("OnlineSubsystem");

		// To include OnlineSubsystemSteam, add it to the plugins section in your uproject file with the Enabled attribute set to true
	}
}
