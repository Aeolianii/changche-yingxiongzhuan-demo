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
    if (-not [regex]::IsMatch($Content, $Pattern)) {
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
    'scripts\Scene2.cs',
    'assets\characters\soldier\picture.png',
    'assets\characters\protagonist\picture.png',
    'assest\Paper UI\PNGs\Backgrounds\BackgroundBar.png'
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
    Assert-Contains $sceneOneContent 'SOLDIER_PORTRAIT\s*:=\s*preload\("res://assets/characters/soldier/picture\.png"\)' 'Scene1 must preload the soldier dialogue portrait.'
    Assert-Contains $sceneOneContent 'GENERAL_PORTRAIT\s*:=\s*preload\("res://assets/characters/protagonist/picture\.png"\)' 'Scene1 must preload the general dialogue portrait.'
    Assert-Contains $sceneOneContent 'func _show_character_dialogue\(' 'Scene1 must distinguish character dialogue from narration.'
    Assert-Contains $sceneOneContent '_show_character_dialogue\("\u4F0F\u6CE2\u5927\u5C06\u519B[^\r\n]+"\s*,\s*"\u5185\u4F8D"\s*,\s*SOLDIER_PORTRAIT\s*,\s*false' 'The attendant summon must use the soldier portrait on the right.'
    Assert-Contains $sceneOneContent '_show_character_dialogue\([^\r\n]+"\u7687\u5E1D"\s*,\s*null\s*,\s*false\s*,\s*"\u5E1D"' 'The emperor dialogue must use the right-side placeholder.'
    Assert-Contains $sceneOneContent '_show_character_dialogue\([^\r\n]+"\u6C34\u5E08\u4E3B\u5E05"\s*,\s*GENERAL_PORTRAIT\s*,\s*true' 'The general reply must use the general portrait on the left.'
    Assert-Contains $sceneOneContent 'func _show_dialogue\([^\)]*\)[\s\S]*?_hide_portrait\(\)[\s\S]*?dialogue_panel\.show\(\)' 'Narration must hide any previous character portrait.'
}

$sceneTwoScript = Join-Path $projectRoot 'scripts\Scene2.cs'
if (Test-Path -LiteralPath $sceneTwoScript -PathType Leaf) {
    $sceneTwoContent = [System.IO.File]::ReadAllText($sceneTwoScript)
    Assert-Contains $sceneTwoContent 'res://assest/Paper UI/PNGs/Backgrounds/BackgroundBar\.png' 'Scene2 must use BackgroundBar.png as its dialogue background.'
    Assert-Contains $sceneTwoContent 'new StyleBoxTexture' 'Scene2 must render its dialogue background through a texture style.'
    if ([regex]::IsMatch($sceneTwoContent, 'BgColor\s*=\s*new Color\(0\.9f,\s*0\.85f,\s*0\.67f')) {
        Add-Failure 'Scene2 must not retain the old beige dialogue background style.'
    }
}

$sceneOneFile = Join-Path $projectRoot 'scenes\palace\palace_demo.tscn'
if (Test-Path -LiteralPath $sceneOneFile -PathType Leaf) {
    $sceneOneScene = [System.IO.File]::ReadAllText($sceneOneFile)
    Assert-Contains $sceneOneScene '\[node name="SceneTransitionTimer" type="Timer" parent="\."' 'Scene1 must contain a one-shot transition timer.'
    Assert-Contains $sceneOneScene '\[node name="TransitionFade" type="ColorRect" parent="UI/Overlay"' 'Scene1 must contain a full-screen transition fade.'
    Assert-Contains $sceneOneScene '\[node name="PortraitDisplay" type="Control" parent="UI/Overlay"' 'Scene1 must contain a reusable portrait display.'
    Assert-Contains $sceneOneScene '\[node name="PortraitImage" type="TextureRect" parent="UI/Overlay/PortraitDisplay"' 'Scene1 must contain a portrait texture node.'
    Assert-Contains $sceneOneScene '\[node name="PlaceholderFrame" type="ColorRect" parent="UI/Overlay/PortraitDisplay"' 'Scene1 must contain an emperor placeholder card.'
    Assert-Contains $sceneOneScene '\[node name="NameText" type="Label" parent="UI/Overlay/PortraitDisplay/NamePlate"' 'Scene1 must contain a portrait name plate.'
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
