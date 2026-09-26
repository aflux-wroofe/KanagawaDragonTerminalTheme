# Kanagawa Terminal Theme

[Kanagawa](https://github.com/rebelot/kanagawa.nvim) colour schemes for Windows Terminal, plus a matching PowerShell profile with a two-line Nerd Font prompt.

## What's included

| File | Purpose |
| --- | --- |
| `KanagawaDragon.json` | Kanagawa Dragon colour scheme (dark, muted) |
| `KanagawaWave.json` | Kanagawa Wave colour scheme (the standard variant) |
| `profile.ps1` | PowerShell tweaks: bold blue directories in `ls`, loads the prompt |
| `KanagawaPrompt.ps1` | Two-line prompt showing path, git branch/status and command duration |
| `install.ps1` | Installs the schemes into Windows Terminal and hooks the profile into PowerShell |

## Requirements

- Windows Terminal
- PowerShell 7+ to run the installer (the prompt also works in Windows PowerShell 5.1)
- A [Nerd Font](https://www.nerdfonts.com/) v3+ for the prompt glyphs, e.g. JetBrainsMono Nerd Font or CaskaydiaCove Nerd Font

## Install

```powershell
git clone https://github.com/aflux-wroofe/KanagawaTerminalTheme.git
cd KanagawaTerminalTheme
./install.ps1
```

Options:

```powershell
./install.ps1 -Variant Wave                          # make Wave the default instead of Dragon
./install.ps1 -FontFace 'CaskaydiaCove Nerd Font'    # set the font for all profiles
./install.ps1 -SkipDefaultScheme                     # add the schemes without applying them
./install.ps1 -WhatIf                                # preview changes
```

The installer is safe to re-run: schemes are replaced by name, the profile hook is rewritten rather than duplicated, and every changed file is backed up first. Your PowerShell profile dot-sources `profile.ps1` from the repo folder, so keep the repo where it is (or re-run the installer after moving it).

### Manual install

1. Open Windows Terminal settings → **Open JSON file**.
2. Paste the contents of `KanagawaDragon.json` and/or `KanagawaWave.json` into the `schemes` array.
3. Set `"colorScheme": "Kanagawa Dragon"` (or `"Kanagawa Wave"`) on a profile or under `profiles.defaults`.
4. Optionally add `. "C:\path\to\KanagawaTerminalTheme\profile.ps1"` to your `$PROFILE`.

## Prompt

```
╭─ ~\Projects\Themes\KanagawaTerminalTheme on  master  1  2 took 3.2s
╰─❯
```

Shows staged, modified, untracked and conflicted file counts, commits ahead/behind upstream, and how long slow commands took. Settings can be changed after the profile loads via `$KanagawaPrompt`, for example:

```powershell
$KanagawaPrompt.ShowGit = $false        # hide git info
$KanagawaPrompt.MinDuration = 5         # only show durations over 5s
$KanagawaPrompt.IconWidth = 1           # use with "Nerd Font Mono" fonts
```

## Credits

Colour palettes from [kanagawa.nvim](https://github.com/rebelot/kanagawa.nvim) by rebelot.

## License

[MIT](LICENSE)
