# Agent instructions — nchrtd22/homebrew-tap

Personal, Linux-only Homebrew tap for GUI apps without a good native channel
(vendor AppImages, tarballs, debs). Target systems are immutable
(Fedora Atomic / Universal Blue / Bluefin): everything installs under
`$HOME` — never `/usr`, `/opt`, or `/etc`.

## The golden path (every cask, no exceptions)

1. Pick the artifact from the vendor's real releases. Compute sha256 from the
   actual download — never copy a hash from a webpage.
2. Check the token is free: no collision with homebrew/cask.
3. Build the cask using the patterns below.
4. `brew audit --cask nchrtd22/tap/<token>` must pass.
5. `brew livecheck --cask <token>` must return the right version.
6. Install for real, launch for real. The first launch is part of the test.
   (PyInstaller onefile apps take 10–30 s to start — that is not a failure.)
7. Verify the zap stanza from reality: after the first launch, confirm the
   config path actually exists (`ls -d ~/.<dir>`). Never guess a zap path.
8. Push, then add the README table row.

## Hard rules (each earned the hard way)

- **`.deb` downloads need `container type: :naked`.** Homebrew has no Deb
  unpack strategy; the embedded `control.tar.zst` magic falls inside brew's
  262-byte sniffing window and its zstd regex is unanchored, so brew
  misclassifies the deb and tries `unzstd` on it. `:naked` stages the file
  untouched so preflight can unpack it ourselves.
- **In `run` steps, args are passed verbatim.** `base: :staged_path` does NOT
  set the working directory. Every `run` that touches relative paths needs
  `base: :staged_path, chdir: "."` — otherwise they resolve against brew's
  own cwd and fail with "No such file or directory".
- **Never `brew tap <name> <local-path>`** — it causes
  `TapRemoteMismatchError`. To test a PR locally, stage it inside the real
  clone:
  `git -C "$(brew --repository nchrtd22/tap)" fetch origin <pr-ref> && git -C "$(brew --repository nchrtd22/tap)" checkout FETCH_HEAD && brew trust --tap nchrtd22/tap`.
- **Rename the staged artifact to a versionless name first** with
  `move "<glob>", "<name>", source_glob: true`, and never interpolate
  `#{version}` inside preflight steps.
- **sha256 from a real download; zap paths from a real first launch.**
  These two are the difference between a receipt and a guess.

## Cask patterns

**AppImage:** `depends_on formula: "squashfs"`, `set_permissions "<app>.AppImage", "+x"`,
`run "<app>.AppImage", args: ["--appimage-extract"], base: :staged_path, chdir: "."`,
then `remove` the AppImage. Wrapper execs `{{staged_path}}/squashfs-root/AppRun`.

**Deb:** `depends_on formula: "binutils"` (provides `ar`) plus
`container type: :naked`. Unpack with
`run "{{HOMEBREW_PREFIX}}/opt/binutils/bin/ar", args: ["x", "<app>.deb"], base: :staged_path, chdir: "."`
then `run "/usr/bin/tar", args: ["--zstd", "-xf", "data.tar.zst"], base: :staged_path, chdir: "."`,
then remove `control.tar.zst`, `debian-binary`, `data.tar.zst` and the deb.
Wrapper execs `{{staged_path}}/usr/bin/<name>`.

**Desktop integration (all GUI casks):** sed the vendor's `.desktop` —
`Exec=` → `{{HOMEBREW_PREFIX}}/bin/<name>`, and fix broken `Icon=` lines
(vendors ship wrong icon paths depressingly often). Copy the desktop file to
`~/.local/share/applications/` and the icon to `~/.local/share/icons/`
(`target_base: :home`). `uninstall_postflight_steps` removes both.

**Livecheck:** `strategy :github_latest` on the releases/latest URL for
GitHub apps (check the tag format — some vendors omit the `v` prefix);
`strategy :electron_builder` + the `latest-linux.yml` URL for
electron-builder apps; if `releases/latest` points at non-binary releases,
use `strategy :github_releases` with a regex on the tag instead.

**Wrapper rationale:** wrappers exec the staged payload so upgrades
(new staged_path) never break the `~/.local/share` desktop entries.

## CI

- `check.yml` — fetch-checks each changed cask on PRs (URL + sha256).
- `smoke-test.yml` — installs each changed cask for real on PRs and on
  pushes to main, proves the `.desktop` entry landed, and runs `brew audit`.
- `bump.yml` — opens bump PRs Mondays 06:00 (secret:
  `HOMEBREW_GITHUB_API_TOKEN`). After changing a workflow file, open bump
  PRs need "Update branch" — a re-run reuses the old workflow file.
- Actions are pinned to commit SHAs; Dependabot proposes pin updates.
- `main` is protected: no force pushes, no deletions.

## Known environment facts

- Homebrew prefix: `/home/linuxbrew/.linuxbrew`
- System `/usr/bin/tar` supports `--zstd`; `ar` comes from the binutils formula
- PyInstaller onefile apps extract roughly their full size to /tmp at every
  launch — size/perf tax belongs in the cask decision, not as a surprise
