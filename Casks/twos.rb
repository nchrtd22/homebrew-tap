cask "twos" do
  os linux: "linux"

  version "1.21.3"
  sha256 "a973d53d5807ce45700bb0b20cdcb0dfae0de6cb9baf2ebd8dbd675e867eecc2"

  url "https://twosapp.com/api/desktop/updates/Twos-#{version}.AppImage"
  name "Twos"
  desc "Native app for writing down the things that matter"
  homepage "https://twosapp.com/"

  livecheck do
    url "https://twosapp.com/api/desktop/updates/latest-linux.yml"
    strategy :electron_builder
  end

  depends_on arch: :x86_64
  depends_on formula: "squashfs"
  depends_on :linux

  binary "twos-wrapper", target: "twos"

  preflight_steps do
    # Avoid version splitting inside the serialised steps.
    move "Twos-*.AppImage", "Twos.AppImage", source_glob: true
    set_permissions "Twos.AppImage", "+x"
    run "Twos.AppImage", args: ["--appimage-extract"], base: :staged_path, chdir: "."
    remove "Twos.AppImage"

    mkdir_p ".local/share/applications", base: :home
    mkdir_p ".local/share/icons", base: :home

    # AppRun (electron-builder) self-locates its AppDir via readlink, so the
    # extracted squashfs-root tree is fully self-contained. Keep the wrapper.
    write_file "twos-wrapper", <<~SH
      #!/bin/sh
      exec "{{staged_path}}/squashfs-root/AppRun" "$@"
    SH
    set_permissions "twos-wrapper", "0755"
  end

  postflight_steps do
    # Point the desktop entry at the Homebrew binary instead of "AppRun".
    # Keeps upstream's --no-sandbox flag, %U args, twos:// URL handler
    # (MimeType) and StartupWMClass intact.
    run "/bin/sed", args: ["-e", "s|^Exec=AppRun|Exec={{HOMEBREW_PREFIX}}/bin/twos|",
                          "{{staged_path}}/squashfs-root/newtwos.desktop"],
                    stdout_path: "newtwos.desktop"
    copy "newtwos.desktop", ".local/share/applications/newtwos.desktop", target_base: :home
    copy "squashfs-root/usr/share/icons/hicolor/512x512/apps/newtwos.png",
         ".local/share/icons/newtwos.png", target_base: :home
  end

  uninstall_postflight_steps do
    remove ".local/share/applications/newtwos.desktop", base: :home
    remove ".local/share/icons/newtwos.png", base: :home
  end

  # Electron userData. The app sets its name at runtime, so both plausible
  # names are listed; adjust after your first run if only one is created.
  zap trash: ["~/.config/Twos", "~/.config/newtwos", "~/.config/desktop-updater"]
end
