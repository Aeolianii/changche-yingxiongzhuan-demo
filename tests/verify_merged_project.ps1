$ErrorActionPreference = 'Stop'

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
    param([string]$Message)
    $script:failures.Add($Message)
}

function Assert-FileExists {
    param([string]$RelativePath)
    $fullPath = Join-Path $projectRoot $RelativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        Add-Failure "Missing file: $RelativePath"
        return $false
    }
    return $true
}

function Assert-Contains {
    param(
        [string]$Content,
        [string]$Pattern,
        [string]$Message
    )
    if ($Content -notmatch $Pattern) {
        Add-Failure $Message
    }
}

function Test-SceneResourceReferences {
    param([string]$RelativeScenePath)

    if (-not (Assert-FileExists $RelativeScenePath)) {
        return
    }

    $scenePath = Join-Path $projectRoot $RelativeScenePath
    $sceneContent = [System.IO.File]::ReadAllText($scenePath)
    $matches = [regex]::Matches($sceneContent, 'path="res://([^\"]+)"')

    foreach ($match in $matches) {
        $relativeResource = $match.Groups[1].Value.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        $resourcePath = Join-Path $projectRoot $relativeResource
        if (-not (Test-Path -LiteralPath $resourcePath -PathType Leaf)) {
            Add-Failure "Broken resource reference in ${RelativeScenePath}: res://$($match.Groups[1].Value)"
        }
    }

    $resourceMatches = [regex]::Matches($sceneContent, '\[ext_resource[^\r\n]*uid="([^\"]+)"[^\r\n]*path="res://([^\"]+)"')
    foreach ($match in $resourceMatches) {
        $declaredUid = $match.Groups[1].Value
        $relativeResource = $match.Groups[2].Value.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        $resourcePath = Join-Path $projectRoot $relativeResource
        $uidSource = $null

        if (Test-Path -LiteralPath ($resourcePath + '.import') -PathType Leaf) {
            $uidSource = $resourcePath + '.import'
        }
        elseif (Test-Path -LiteralPath ($resourcePath + '.uid') -PathType Leaf) {
            $uidSource = $resourcePath + '.uid'
        }
        elseif ([System.IO.Path]::GetExtension($resourcePath) -eq '.tscn') {
            $uidSource = $resourcePath
        }

        if ($uidSource) {
            $uidContent = [System.IO.File]::ReadAllText($uidSource)
            $uidMatch = [regex]::Match($uidContent, 'uid(?:=)?"?(uid://[a-z0-9]+)')
            if ($uidMatch.Success -and $uidMatch.Groups[1].Value -ne $declaredUid) {
                Add-Failure "Stale UID in ${RelativeScenePath}: $declaredUid should be $($uidMatch.Groups[1].Value) for res://$($match.Groups[2].Value)"
            }
        }
    }
}

$requiredFiles = @(
    'project.godot',
    'NanjiangFleet.csproj',
    'scenes\palace\palace_demo.tscn',
    'scenes\Scene2.tscn',
    'scripts\palace_demo.gd',
    'scripts\Scene2.cs'
)

foreach ($requiredFile in $requiredFiles) {
    [void](Assert-FileExists $requiredFile)
}

$projectFile = Join-Path $projectRoot 'project.godot'
if (Test-Path -LiteralPath $projectFile -PathType Leaf) {
    $projectContent = [System.IO.File]::ReadAllText($projectFile)
    Assert-Contains $projectContent 'run/main_scene="res://scenes/palace/palace_demo\.tscn"' 'Project must start from Scene1.'
    Assert-Contains $projectContent 'config/features=PackedStringArray\([^\r\n]*"C#"' 'Project must retain the C# feature.'
    Assert-Contains $projectContent 'project/assembly_name="NanjiangFleet"' 'Project must retain the Scene2 .NET assembly name.'
    Assert-Contains $projectContent '"physical_keycode":32' 'The interact action must include Space.'
    Assert-Contains $projectContent '"physical_keycode":69' 'The interact action must include E.'
}

$sceneOneScript = Join-Path $projectRoot 'scripts\palace_demo.gd'
if (Test-Path -LiteralPath $sceneOneScript -PathType Leaf) {
    $sceneOneContent = [System.IO.File]::ReadAllText($sceneOneScript)
    Assert-Contains $sceneOneContent 'NEXT_SCENE_PATH\s*:=\s*"res://scenes/Scene2\.tscn"' 'Scene1 must declare Scene2 as its next scene.'
    Assert-Contains $sceneOneContent 'SCENE_TRANSITION_DELAY\s*:=\s*2\.5' 'Scene1 must use the documented 2.5 second transition delay.'
    Assert-Contains $sceneOneContent 'change_scene_to_file\(NEXT_SCENE_PATH\)' 'Scene1 must switch through SceneTree.change_scene_to_file().'
    Assert-Contains $sceneOneContent 'transition_started' 'Scene1 must guard against duplicate transitions.'
    Assert-Contains $sceneOneContent 'if change_result == OK:' 'Scene1 must inspect the scene change result.'
    Assert-Contains $sceneOneContent 'continue_button\.disabled = false' 'Scene1 must restore the continue button after a failed scene change.'
    Assert-Contains $sceneOneContent 'transition_fade\.modulate = Color\([^\r\n]+\)[\s\S]*_show_dialogue\("[^"]+"\)[\s\S]*_set_continue_text\("[^"]+"\)' 'Scene1 must explain a failed Scene2 load and allow retry.'
}

$sceneOneFile = Join-Path $projectRoot 'scenes\palace\palace_demo.tscn'
if (Test-Path -LiteralPath $sceneOneFile -PathType Leaf) {
    $sceneOneScene = [System.IO.File]::ReadAllText($sceneOneFile)
    Assert-Contains $sceneOneScene '\[node name="SceneTransitionTimer" type="Timer" parent="\."' 'Scene1 must contain a one-shot transition timer.'
    Assert-Contains $sceneOneScene '\[node name="TransitionFade" type="ColorRect" parent="UI/Overlay"' 'Scene1 must contain a full-screen transition fade.'
}

Test-SceneResourceReferences 'scenes\palace\palace_demo.tscn'
Test-SceneResourceReferences 'scenes\characters\player.tscn'
Test-SceneResourceReferences 'scenes\characters\npc.tscn'
Test-SceneResourceReferences 'scenes\Scene2.tscn'

if ($failures.Count -gt 0) {
    Write-Host "Merged project verification failed with $($failures.Count) issue(s):" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'Merged project static verification passed.' -ForegroundColor Green
