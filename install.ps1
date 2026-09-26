#Requires -Version 7.0
<#
.SYNOPSIS
    Installs the Kanagawa colour schemes into Windows Terminal and hooks the
    Kanagawa profile (ls colours + prompt) into your PowerShell profiles.

.DESCRIPTION
    Safe to run again: schemes are replaced by name and the profile hook is a
    marked block that gets rewritten, never duplicated. Every file it changes
    is backed up next to the original first.

    Your PowerShell profiles dot-source profile.ps1 from this folder, so keep the
    repo where it is (or run the installer again after moving it).

.EXAMPLE
    ./install.ps1                      # Dragon as the default scheme
.EXAMPLE
    ./install.ps1 -Variant Wave -FontFace 'CaskaydiaCove Nerd Font'
.EXAMPLE
    ./install.ps1 -WhatIf              # show what would change
.EXAMPLE
    ./install.ps1 -Verbose             # also show file paths and backups
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # Scheme to make the default for all Windows Terminal profiles
    [ValidateSet('Dragon', 'Wave')]
    [string]$Variant = 'Dragon',

    # Add the schemes but leave every profile's colour scheme alone
    [switch]$SkipDefaultScheme,

    # Nerd Font to use for all Windows Terminal profiles, e.g. 'JetBrainsMono Nerd Font'
    [string]$FontFace,

    # Windows Terminal settings files to update (found automatically if omitted)
    [string[]]$TerminalSettingsPath,

    # PowerShell profiles to hook into (PowerShell 7 and Windows PowerShell 5.1 if omitted)
    [string[]]$ProfilePath
)

$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$utf8 = [Text.UTF8Encoding]::new($false)
$backups = [Collections.Generic.List[string]]::new()

# ---------------------------------------------------------------- Output

function Write-Section([string]$Title) {
    Write-Host "`n  $Title" -ForegroundColor Blue
}

# One aligned line per result: ok (changed), same (nothing to do), note (needs attention)
function Write-Result([string]$Label, [string]$Detail, [ValidateSet('ok', 'same', 'note')][string]$State = 'ok') {
    $mark, $colour = switch ($State) {
        'ok'   { [char]0x2713, 'Green' }     # ✓
        'same' { [char]0x00B7, 'DarkGray' }  # ·
        'note' { '!', 'Yellow' }
    }
    Write-Host "    $mark " -ForegroundColor $colour -NoNewline
    Write-Host $Label.PadRight(22) -NoNewline -ForegroundColor ($State -eq 'same' ? 'DarkGray' : 'Gray')
    Write-Host $Detail -ForegroundColor DarkGray
}

function Backup-File([string]$Path) {
    if (Test-Path $Path) {
        $backup = "$Path.kanagawa-backup-$stamp"
        Copy-Item $Path $backup
        $backups.Add($backup)
        Write-Verbose "Backed up $Path to $backup"
    }
}

$check = [char]0x2713
Write-Host "`n  Kanagawa $([char]0x00B7) $Variant" -ForegroundColor Cyan
if ($WhatIfPreference) { Write-Host '  dry run: nothing will be written' -ForegroundColor DarkGray }

# ---------------------------------------------------------------- Windows Terminal

$terminalNames = @{
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"        = 'Windows Terminal'
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json" = 'Windows Terminal Preview'
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"                                          = 'Windows Terminal (unpackaged)'
}
if (-not $TerminalSettingsPath) {
    $TerminalSettingsPath = $terminalNames.Keys | Where-Object { Test-Path $_ } | Sort-Object
}

$schemes = 'KanagawaDragon.json', 'KanagawaWave.json' | ForEach-Object {
    Get-Content (Join-Path $PSScriptRoot $_) -Raw | ConvertFrom-Json
}
$schemeNames = $schemes.name
$defaultScheme = "Kanagawa $Variant"
$terminalFonts = @()

if (-not $TerminalSettingsPath) {
    Write-Section 'Windows Terminal'
    Write-Result 'Not found' 'open Windows Terminal once, then run this again' note
}

foreach ($settingsFile in $TerminalSettingsPath) {
    Write-Section ($terminalNames[$settingsFile] ?? $settingsFile)
    Write-Verbose "Settings file: $settingsFile"
    $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json  # PowerShell 7 accepts the comments WT allows
    $before = $settings | ConvertTo-Json -Depth 32
    $notes = @()

    # Replace earlier copies of our schemes where they sit, append new ones
    $list = [Collections.Generic.List[object]]@($settings.schemes | Where-Object { $_ })
    $added = $updated = 0
    $fingerprint = { param($o) ($o.PSObject.Properties | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ';' }
    foreach ($scheme in $schemes) {
        $index = @($list.name).IndexOf($scheme.name)
        if ($index -lt 0) { $list.Add($scheme); $added++ }
        elseif ((& $fingerprint $list[$index]) -ne (& $fingerprint $scheme)) { $list[$index] = $scheme; $updated++ }
    }
    $settings | Add-Member -NotePropertyName schemes -NotePropertyValue $list.ToArray() -Force
    $schemeSummary = ($schemeNames -replace '^Kanagawa ') -join ', '
    if ($added) { Write-Result 'Schemes added' $schemeSummary }
    elseif ($updated) { Write-Result 'Schemes updated' $schemeSummary }
    else { Write-Result 'Schemes' "$schemeSummary, already installed" same }

    if ($settings.profiles -is [array]) {
        # Old settings format: no profiles.defaults to write to
        if (-not $SkipDefaultScheme -or $FontFace) {
            Write-Result 'Default scheme' 'set it in Settings > Defaults > Appearance (old settings format)' note
        }
        $settingsFont = $null
    } else {
        if (-not $settings.profiles.defaults) {
            $settings.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) -Force
        }
        $defaults = $settings.profiles.defaults

        if (-not $SkipDefaultScheme) {
            if ($defaults.colorScheme -eq $defaultScheme) {
                Write-Result 'Default scheme' "$defaultScheme, already set" same
            } else {
                $defaults | Add-Member -NotePropertyName colorScheme -NotePropertyValue $defaultScheme -Force
                Write-Result 'Default scheme' $defaultScheme
            }

            # A scheme set on a single profile beats the default, so point it out rather than override it
            $settings.profiles.list | Where-Object { $_.colorScheme -and $_.colorScheme -notin $schemeNames } | ForEach-Object {
                $notes += , @($_.name, "keeps its own scheme ($($_.colorScheme))")
            }
        }

        if ($FontFace) {
            if (-not $defaults.font) {
                $defaults | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{}) -Force
            }
            if ($defaults.font.face -eq $FontFace) {
                Write-Result 'Font' "$FontFace, already set" same
            } else {
                $defaults.font | Add-Member -NotePropertyName face -NotePropertyValue $FontFace -Force
                Write-Result 'Font' $FontFace
            }
        }
        $settingsFont = $defaults.font.face ?? $defaults.fontFace ?? 'Cascadia Mono'  # WT's own default
    }
    $terminalFonts += $settingsFont

    foreach ($note in $notes) { Write-Result $note[0] $note[1] note }

    # Comments in settings.json don't survive the rewrite; the backup keeps them
    $after = $settings | ConvertTo-Json -Depth 32
    if ($after -ne $before -and $PSCmdlet.ShouldProcess($settingsFile, 'Update Windows Terminal settings')) {
        Backup-File $settingsFile
        [IO.File]::WriteAllText($settingsFile, $after, $utf8)
    }
}

# ---------------------------------------------------------------- PowerShell profiles

$documents = [Environment]::GetFolderPath('MyDocuments')  # follows OneDrive folder redirection
$profileNames = @{
    "$documents\PowerShell\Microsoft.PowerShell_profile.ps1"        = 'PowerShell 7'
    "$documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" = 'Windows PowerShell 5.1'
}
if (-not $ProfilePath) {
    $ProfilePath = $profileNames.Keys | Sort-Object
}

$begin = '# >>> KanagawaTerminalTheme >>>'
$end = '# <<< KanagawaTerminalTheme <<<'
$kanagawaProfile = (Join-Path $PSScriptRoot 'profile.ps1').Replace("'", "''")
$block = @(
    $begin
    "if (Test-Path '$kanagawaProfile') { . '$kanagawaProfile' }"
    $end
) -join [Environment]::NewLine

Write-Section 'PowerShell profiles'
foreach ($target in $ProfilePath) {
    $label = $profileNames[$target] ?? (Split-Path $target -Leaf)
    Write-Verbose "Profile file: $target"
    $existing = if (Test-Path $target) { Get-Content $target -Raw } else { '' }
    $pattern = "(?s)$([regex]::Escape($begin)).*?$([regex]::Escape($end))"

    if ($existing -match $pattern) {
        $updated = [regex]::Replace($existing, $pattern, $block.Replace('$', '$$'))
        $action = 'hook updated'
    } else {
        $separator = if ($existing -and -not $existing.EndsWith("`n")) { [Environment]::NewLine * 2 } elseif ($existing) { [Environment]::NewLine } else { '' }
        $updated = $existing + $separator + $block + [Environment]::NewLine
        $action = if ($existing) { 'hooked in' } else { 'profile created' }
    }

    if ($updated -eq $existing) {
        Write-Result $label 'already hooked in' same
    } elseif ($PSCmdlet.ShouldProcess($target, 'Add Kanagawa to PowerShell profile')) {
        Backup-File $target
        New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
        # UTF-8 with BOM so Windows PowerShell 5.1 reads any non-ASCII already in the profile correctly
        [IO.File]::WriteAllText($target, $updated, [Text.UTF8Encoding]::new($true))
        Write-Result $label $action
    }
}

$policy = Get-ExecutionPolicy
if ($policy -in 'Restricted', 'AllSigned') {
    Write-Result 'Execution policy' "'$policy' stops profiles from running (see about_Execution_Policies)" note
}

# ---------------------------------------------------------------- Font

$nerdFonts = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts', 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' |
    Where-Object { Test-Path $_ } |
    ForEach-Object { (Get-Item $_).GetValueNames() } |
    Where-Object { $_ -match '^(.*?(Nerd Font( Mono| Propo)?|NF[MP]?))\b' } |
    ForEach-Object { $Matches[1] } |  # family name without weight/style
    Sort-Object -Unique

if (-not $FontFace) {
    Write-Section 'Font'
    $terminalFont = $terminalFonts | Select-Object -First 1
    if (-not $nerdFonts) {
        Write-Result 'No Nerd Font' 'the prompt needs one: nerdfonts.com/font-downloads' note
    } elseif ($terminalFont -and $terminalFont -match 'Nerd Font|\bNF[MP]?\b') {
        Write-Result 'Terminal font' "$terminalFont, a Nerd Font" same
    } else {
        Write-Result 'Terminal font' "$terminalFont isn't a Nerd Font" note
        Write-Host "      re-run with -FontFace '$($nerdFonts[0])'  (installed: $($nerdFonts -join ', '))" -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------------- Done

Write-Host ''
if ($backups.Count) {
    Write-Host "  Backups saved beside each file as *.kanagawa-backup-$stamp" -ForegroundColor DarkGray
}
if (-not $WhatIfPreference) {
    Write-Host "  $check Done. Open a new tab to see it." -ForegroundColor Green
}
Write-Host ''
