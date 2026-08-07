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
    'scenes\ui\exploration_hud.tscn',
    'scenes\ui\chapter_transition.tscn',
    'scripts\palace_demo.gd',
    'scripts\Scene2.cs',
    'scripts\exploration_hud.gd',
    'scripts\ui\chapter_transition.gd',
    'shaders\menu_blur.gdshader',
    'assets\ui\system_menu\system_menu_frame.png',
    'assets\ui\system_menu\menu_button.png',
    'assets\ui\system_menu\close_button.png',
    'assets\ui\exploration_hud\player_status_frame.png',
    'assets\ui\exploration_hud\quest_tracker_frame.png',
    'assets\ui\exploration_hud\function_button.png',
    'assets\ui\chapter_transition\southbound_journey.png',
    'assets\ui\icons\hud_quest.png',
    'assets\ui\icons\hud_character.png',
    'assets\ui\icons\hud_inventory.png',
    'assets\ui\icons\hud_ship.png',
    'assets\ui\icons\hud_menu.png',
    'assets\ui\icons\menu_continue.png',
    'assets\ui\icons\menu_save.png',
    'assets\ui\icons\menu_load.png',
    'assets\ui\icons\menu_settings.png',
    'assets\ui\icons\menu_return_title.png',
    'assets\ui\icons\menu_exit.png',
    'tests\test_system_menu_exit.gd',
    'tests\test_chapter_transition_visual.gd',
    'tests\test_scene_two_dialogue_patrol.gd',
    'assets\characters\soldier\picture.png',
    'assets\characters\protagonist\picture.png',
    'assets\characters\magistrate\standard\idle\down\1.png',
    'assets\characters\protagonist\standard\walk\down\1.png',
    'assets\characters\soldier\standard\walk\down\1.png',
    'assets\ui\dialogue\ink_dialogue_backdrop.png',
    'assets\ui\dialogue\ink_speaker_nameplate.png',
    'assets\backgrounds\naval_base.png'
)

foreach ($requiredFile in $requiredFiles) {
    [void](Assert-FileExists $requiredFile)
}

if (Test-Path -LiteralPath (Join-Path $projectRoot 'assest')) {
    Add-Failure 'The misspelled assest directory must be fully merged into assets.'
}

$staleImportFiles = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'assets') -Recurse -File -Filter '*.import' |
    Where-Object { [System.IO.File]::ReadAllText($_.FullName).Contains('res://assest') }
if ($staleImportFiles) {
    Add-Failure 'Asset import metadata must not reference res://assest.'
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
    Assert-Contains $sceneOneContent 'chapter_transition\.call\("play"\)' 'Scene1 must play the chapter transition before loading Scene2.'
    Assert-Contains $sceneOneContent 'set_meta\(CHAPTER_ENTRY_META, true\)' 'Scene1 must mark Scene2 as entered through the chapter transition.'
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
    Assert-Contains $sceneOneContent 'StoryState\.WAIT_TALK[\s\S]*StoryState\.GO_TO_EMPEROR' 'Scene1 must restrict the exploration HUD to free-movement story states.'
    Assert-Contains $sceneOneContent 'set_exploration_visible' 'Scene1 must synchronize exploration HUD visibility.'
    Assert-Contains $sceneOneContent 'menu_visibility_changed' 'Scene1 must pause and resume player controls from the shared menu signal.'
}

$sceneTwoScript = Join-Path $projectRoot 'scripts\Scene2.cs'
if (Test-Path -LiteralPath $sceneTwoScript -PathType Leaf) {
    $sceneTwoContent = [System.IO.File]::ReadAllText($sceneTwoScript)
    Assert-Contains $sceneTwoContent 'AssetRoot\s*=\s*"res://assets/characters"' 'Scene2 must load characters from the unified assets directory.'
    Assert-Contains $sceneTwoContent '\$"\{AssetRoot\}/soldier"' 'Scene2 must load the complete soldier asset set.'
    Assert-Contains $sceneTwoContent 'res://assets/ui/dialogue/ink_dialogue_backdrop\.png' 'Scene2 must use the generated ink dialogue backdrop.'
    Assert-Contains $sceneTwoContent 'res://assets/ui/dialogue/ink_speaker_nameplate\.png' 'Scene2 must use the generated ink speaker nameplate.'
    Assert-Contains $sceneTwoContent 'new StyleBoxTexture' 'Scene2 must render its dialogue background through a texture style.'
    Assert-Contains $sceneTwoContent 'set_exploration_visible' 'Scene2 must synchronize exploration HUD visibility.'
    Assert-Contains $sceneTwoContent 'IsMenuOpen\(\)' 'Scene2 must block movement and interaction while the shared menu is open.'
    Assert-Contains $sceneTwoContent 'ConsumeChapterEntryFlag\(\)' 'Scene2 must consume the one-shot chapter entry flag.'
    Assert-Contains $sceneTwoContent 'StartArrivalDialogue\(\)' 'Scene2 must show the deputy greeting after the chapter transition.'
    Assert-Contains $sceneTwoContent 'ActivateArrivalTask\(\)' 'Scene2 must activate the patrol task after the deputy greeting.'
    Assert-Contains $sceneTwoContent 'LeftSoldierRole\s*=\s*"patrol_soldier_left"' 'Scene2 must identify the left patrol soldier independently.'
    Assert-Contains $sceneTwoContent 'RightSoldierRole\s*=\s*"patrol_soldier_right"' 'Scene2 must identify the right patrol soldier independently.'
    Assert-Contains $sceneTwoContent 'OfficerRole\s*=\s*"patrol_officer"' 'Scene2 must keep the patrol officer distinct from the magistrate.'
    Assert-Contains $sceneTwoContent '_heardSoldierReports\.Add\(soldierRole\)' 'Scene2 must deduplicate soldier reports by role.'
    Assert-Contains $sceneTwoContent 'CompleteOfficerReport\(\)' 'Scene2 must complete patrol through the officer report.'
    Assert-Contains $sceneTwoContent 'CompleteMagistrateBriefing\(\)' 'Scene2 must unlock the drill through the magistrate briefing.'
    Assert-Contains $sceneTwoContent 'set_main_task_progress' 'Scene2 must project patrol progress into the shared HUD.'
    if ([regex]::IsMatch($sceneTwoContent, 'BgColor\s*=\s*new Color\(0\.9f,\s*0\.85f,\s*0\.67f')) {
        Add-Failure 'Scene2 must not retain the old beige dialogue background style.'
    }
}

$hudScript = Join-Path $projectRoot 'scripts\exploration_hud.gd'
if (Test-Path -LiteralPath $hudScript -PathType Leaf) {
    $hudContent = [System.IO.File]::ReadAllText($hudScript)
    $menuEntries = @(
        @('\u7EE7\u7EED\u6E38\u620F', 'continue game'),
        @('\u4FDD\u5B58\u8FDB\u5EA6', 'save game'),
        @('\u8BFB\u53D6\u8FDB\u5EA6', 'load game'),
        @('\u6E38\u620F\u8BBE\u7F6E', 'settings'),
        @('\u8FD4\u56DE\u6807\u9898', 'return to title'),
        @('\u9000\u51FA\u6E38\u620F', 'exit game')
    )
    foreach ($entry in $menuEntries) {
        Assert-Contains $hudContent $entry[0] "System menu is missing the $($entry[1]) entry."
    }
    if ([regex]::IsMatch($hudContent, '\u65B0\u624B\u6559\u7A0B')) {
        Add-Failure 'System menu must not include the tutorial entry.'
    }
    Assert-Contains $hudContent 'MENU_BLUR_SHADER' 'System menu must use the shared blur shader.'
    Assert-Contains $hudContent 'assets/ui/system_menu/system_menu_frame\.png' 'System menu must load the generated frame texture.'
    Assert-Contains $hudContent 'assets/ui/system_menu/menu_button\.png' 'System menu must load the generated button texture.'
    Assert-Contains $hudContent 'assets/ui/system_menu/close_button\.png' 'System menu must load the generated close-button texture.'
    Assert-Contains $hudContent 'get_tree\(\)\.quit\(\)' 'ExitGameButton must quit the running game.'
    Assert-Contains $hudContent 'func set_main_task_progress\(' 'Exploration HUD must expose task title, objective and stage updates.'
    Assert-Contains $hudContent '\u8BE5\u529F\u80FD\u5373\u5C06\u5B9E\u73B0' 'Unfinished system menu entries must show the documented placeholder message.'
}

$characterActorScript = Join-Path $projectRoot 'scripts\character_actor.gd'
if (Test-Path -LiteralPath $characterActorScript -PathType Leaf) {
    $characterActorContent = [System.IO.File]::ReadAllText($characterActorScript)
    Assert-Contains $characterActorContent 'res://assets/characters/%s/standard/%s/%s' 'Scene1 characters must load idle and walk frames from each complete standard asset set.'
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
    Assert-Contains $sceneOneScene 'instance=ExtResource\("8_hud"\)' 'Scene1 must instance the shared exploration HUD.'
    Assert-Contains $sceneOneScene 'instance=ExtResource\("9_chapter"\)' 'Scene1 must instance the chapter transition UI.'
    Assert-Contains $sceneOneScene 'assets/ui/dialogue/ink_dialogue_backdrop\.png' 'Scene1 must share the generated ink dialogue backdrop.'
    Assert-Contains $sceneOneScene 'assets/ui/dialogue/ink_speaker_nameplate\.png' 'Scene1 must share the generated ink speaker nameplate.'
}

Test-SceneResourceReferences 'scenes\palace\palace_demo.tscn'
Test-SceneResourceReferences 'scenes\characters\player.tscn'
Test-SceneResourceReferences 'scenes\characters\npc.tscn'
Test-SceneResourceReferences 'scenes\Scene2.tscn'
Test-SceneResourceReferences 'scenes\ui\exploration_hud.tscn'
Test-SceneResourceReferences 'scenes\ui\chapter_transition.tscn'

if ($failures.Count -gt 0) {
    Write-Host "Merged project verification failed with $($failures.Count) issue(s):" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'Merged project static verification passed.' -ForegroundColor Green
