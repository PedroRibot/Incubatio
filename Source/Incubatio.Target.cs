// Fill out your copyright notice in the Description page of Project Settings.

using UnrealBuildTool;
using System.Collections.Generic;

public class IncubatioTarget : TargetRules
{
	public IncubatioTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Game;
		DefaultBuildSettings = BuildSettingsVersion.V4;

		ExtraModuleNames.AddRange( new string[] { "Incubatio", "ShaderModule" } );
        ExtraModuleNames.Add("ShaderModule");
    }
}
