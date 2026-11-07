cask "qualcoder" do
  os linux: "linux"

  version "4.0"
  sha256 "598aec2c4cd6b972896629971a3b9317b803c9e77ebe3d8e4f20cbfc610be5e5"

  # Note: QualCoder tags have NO "v" prefix
  url "https://github.com/ccbogel/QualCoder/releases/download/#{version}/qualcoder_#{version}_amd64.deb"
  name "QualCoder"
  desc "Qualitative data analysis for text, images, audio, video"
  homepage "https://github.com/ccbogel/QualCoder"

  livecheck do
    url "https://github.com/ccbogel/QualCoder/releases/latest"
    strategy :github_latest
  end

  depends_on arch: :x86_64
  depends_on formula: "binutils"   # provides `ar`; pulls in zstd for tar
  depends_on :linux

  # Homebrew would auto-detect this deb as a zstd archive: there is no Deb
  # unpack strategy, and the embedded control.tar.zst (zstd magic at offset
  # 132) falls inside the 262-byte magic-number window of the unanchored
  # zstd regex -> brew tries `unzstd` on the deb and fails. `:naked` means
  # "stage the file as-is"; preflight unpacks it ourselves.
  container type: :naked

  binary "qualcoder-wrapper", target: "qualcoder"

  preflight_steps do
    # Unpack the deb (ar archive, zstd-compressed data.tar):
    #   ar x qualcoder.deb                    -> data.tar.zst
    #   /usr/bin/tar --zstd -xf data.tar.zst   -> ./usr/bin/qualcoder
    #                                             ./usr/share/applications/QualCoder.desktop
    #                                             ./usr/share/icons/qualcoder.xpm
    # The payload is a PyInstaller onefile ELF — bundles Python + PySide6
    # (its own Qt), so no system toolkit is needed.
    # Avoid version splitting inside the serialised steps.
    move "qualcoder_*_amd64.deb", "qualcoder.deb", source_glob: true
    run "{{HOMEBREW_PREFIX}}/opt/binutils/bin/ar", args: ["x", "qualcoder.deb"],
                                                    base: :staged_path, chdir: "."
    remove "control.tar.zst", base: :staged_path
    remove "debian-binary", base: :staged_path
    # chdir is load-bearing: run args are passed verbatim, so without
    # chdir: "." tar looks for data.tar.zst in brew's own cwd, not in
    # staged_path (verified: install failed exactly this way on 4.0).
    run "/usr/bin/tar", args: ["--zstd", "-xf", "data.tar.zst"], base: :staged_path, chdir: "."
    remove "data.tar.zst", base: :staged_path
    remove "qualcoder.deb", base: :staged_path

    mkdir_p ".local/share/applications", base: :home
    mkdir_p ".local/share/icons", base: :home

    # Wrapper: PyInstaller onefile is self-locating, but a wrapper keeps
    # the pattern consistent and survives staged_path version changes.
    write_file "qualcoder-wrapper", <<~SH
      #!/bin/sh
      exec "{{staged_path}}/usr/bin/qualcoder" "$@"
    SH
    set_permissions "qualcoder-wrapper", "0755"
  end

  postflight_steps do
    # Fix the vendor's desktop file (their Icon= points at a .png that the
    # deb doesn't ship — it ships an .xpm) and point Exec at our binary.
    run "/bin/sed",
        args: [
          "-e", "s|^Exec=/usr/bin/qualcoder|Exec={{HOMEBREW_PREFIX}}/bin/qualcoder|",
          "-e", "s|^Icon=/usr/share/icons/qualcoder.png|Icon=qualcoder|",
          "{{staged_path}}/usr/share/applications/QualCoder.desktop"
        ],
        stdout_path: "QualCoder.desktop"
    copy "QualCoder.desktop", ".local/share/applications/QualCoder.desktop", target_base: :home
    copy "usr/share/icons/qualcoder.xpm", ".local/share/icons/qualcoder.xpm", target_base: :home
  end

  uninstall_postflight_steps do
    remove ".local/share/applications/QualCoder.desktop", base: :home
    remove ".local/share/icons/qualcoder.xpm", base: :home
  end

  # QualCoder keeps its settings in ~/.qualcoder (project files live in
  # the user's own project folders and are untouched by zap).
  # TODO: verify at first launch before pushing.
  zap trash: ["~/.qualcoder"]
end
