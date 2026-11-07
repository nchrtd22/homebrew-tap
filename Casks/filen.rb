cask "filen" do
  os linux: "linux"

  version "3.0.53"
  sha256 "888298db82fa43d7be3feeeba86a2f745dbc1ffdf1efabe2cca5144a996461f2"

  url "https://cdn.filen.io/@filen/desktop/release/v#{version}/Filen_linux_x86_64.AppImage"
  name "Filen"
  desc "End-to-end encrypted cloud storage desktop client"
  homepage "https://filen.io/"

  livecheck do
    url "https://cdn.filen.io/@filen/desktop/release/latest/latest-linux.yml"
    strategy :electron_builder
  end

  depends_on arch: :x86_64
  depends_on formula: "squashfs"
  depends_on :linux

  binary "filen-wrapper", target: "filen"

  preflight_steps do
    # The staged filename has no version in it, so no rename needed.
    set_permissions "Filen_linux_x86_64.AppImage", "+x"
    run "Filen_linux_x86_64.AppImage", args: ["--appimage-extract"], base: :staged_path, chdir: "."
    remove "Filen_linux_x86_64.AppImage"

    mkdir_p ".local/share/applications", base: :home
    mkdir_p ".local/share/icons", base: :home

    # AppRun (electron-builder) self-locates its AppDir via readlink, so the
    # extracted squashfs-root tree is fully self-contained. Keep the wrapper.
    write_file "filen-wrapper", <<~SH
      #!/bin/sh
      exec "{{staged_path}}/squashfs-root/AppRun" "$@"
    SH
    set_permissions "filen-wrapper", "0755"
  end

  postflight_steps do
    # Point the desktop entry at the Homebrew binary instead of "AppRun".
    run "/bin/sed", args: ["-e", "s|^Exec=AppRun|Exec={{HOMEBREW_PREFIX}}/bin/filen|",
                          "{{staged_path}}/squashfs-root/Filen.desktop"],
                    stdout_path: "Filen.desktop"
    copy "Filen.desktop", ".local/share/applications/Filen.desktop", target_base: :home
    copy "squashfs-root/usr/share/icons/hicolor/1024x1024/apps/Filen.png",
         ".local/share/icons/Filen.png", target_base: :home
  end

  uninstall_postflight_steps do
    remove ".local/share/applications/Filen.desktop", base: :home
    remove ".local/share/icons/Filen.png", base: :home
  end

  # Electron userData (verified on first run) + electron-updater cache
  # (updaterCacheDirName from resources/app-update.yml). ~/.config/filen-cli
  # belongs to the separate Filen CLI and is deliberately not zapped.
  zap trash: ["~/.config/@filen", "~/.config/@filendesktop-updater"]
end
# fetch-check smoke test
