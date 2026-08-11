$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$activeRoot = Join-Path $projectRoot 'assets\characters\protagonist\standard'
$candidateRoot = Join-Path $projectRoot 'assets\characters\protagonist_candidate\standard'
$expectedNames = @('1.png', '2.png', '3.png', '4.png')
$directions = @('down', 'left', 'right', 'up')

foreach ($action in @('idle', 'walk')) {
    foreach ($direction in $directions) {
        $activeDirectory = Join-Path $activeRoot "$action\$direction"
        $candidateDirectory = Join-Path $candidateRoot "$action\$direction"
        $actualNames = @(Get-ChildItem -LiteralPath $activeDirectory -Filter '*.png' -File | Sort-Object Name | Select-Object -ExpandProperty Name)
        if (Compare-Object -ReferenceObject $expectedNames -DifferenceObject $actualNames) {
            throw "$action/$direction must contain exactly 1.png..4.png; found: $($actualNames -join ', ')"
        }

        foreach ($name in $expectedNames) {
            $activePath = Join-Path $activeDirectory $name
            $candidatePath = Join-Path $candidateDirectory $name
            $activeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $activePath).Hash
            $candidateHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $candidatePath).Hash
            if ($activeHash -ne $candidateHash) {
                throw "$action/$direction/$name does not match the approved young naval protagonist frame."
            }
        }
    }
}

$sceneTwoScript = [System.IO.File]::ReadAllText((Join-Path $projectRoot 'scripts\scene_2.gd'))
if ($sceneTwoScript -notmatch '_add_animation_frames\(frames, "idle_%s" % direction, [^\r\n]+, 4, 2\.5\)') {
    throw 'Scene 2 must load four protagonist idle frames per direction.'
}
if ($sceneTwoScript -notmatch '_add_animation_frames\(frames, "walk_%s" % direction, [^\r\n]+, 4, 10\.0\)') {
    throw 'Scene 2 must load four protagonist walk frames per direction.'
}

Write-Output 'PASS: active protagonist has exactly 32 approved young naval commander frames.'
