# nchrtd22 Homebrew Tap

Personal Homebrew tap of Linux casks — managed installs for apps that ship only as AppImages or debs. Each cask provides full desktop integration, and versions are kept current by an automated weekly check.

## Usage

```bash
brew install --cask nchrtd22/tap/<cask>
```

Homebrew adds the tap automatically on first install, or you can add it up front:

```bash
brew tap nchrtd22/homebrew-tap
```

## Casks

| Cask | What it installs |
|-------|------------------|
| `filen` | Filen — end-to-end encrypted cloud storage client |
| `neo` | NEO — distraction-free word processor for writers |
| `noson-linux` | Noson — SONOS system controller (also installs `noson-cli`) |
| `qualcoder` | QualCoder — qualitative data analysis for text, images, audio, video |
| `twos` | Twos — notes and journaling desktop app |

## Notes

- **Requirements:** [Homebrew](https://brew.sh) on Linux (x86_64)
- **Updates:** a GitHub Actions workflow checks for new releases weekly and opens bump PRs — pick them up with `brew update && brew upgrade`
- **Desktop integration:** apps appear in your launcher after install (`.desktop` entries in `~/.local/share/applications`, icons in `~/.local/share/icons`)
- Inspired by and based on https://github.com/agammemnon/homebrew-tap
