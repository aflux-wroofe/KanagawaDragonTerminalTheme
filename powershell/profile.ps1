# Kanagawa PowerShell tweaks (works with any variant). Dot-source this from $PROFILE.

# Directories in ls: bold Kanagawa blue text, no background ($PSStyle is PowerShell 7.2+)
if ($PSStyle) { $PSStyle.FileInfo.Directory = "$([char]27)[1;34m" }

# Two-line prompt with Nerd Font glyphs
. "$PSScriptRoot\KanagawaPrompt.ps1"
