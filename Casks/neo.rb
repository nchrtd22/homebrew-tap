cask "neo" do
  os linux: "linux"

  version "1.6.4"
  sha256 "964807089ade35cf28e4b6ea02438ce22edf9ee28a9460c5ea8ae959c7e0565c"

  url "https://github.com/hughhowey/neo/releases/download/v#{version}/NEO-#{version}.AppImage"
  name "NEO"
  desc "Distraction-free word processor for authors"
  homepage "https://github.com/hughhowey/neo"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :x86_64
  depends_on formula: "squashfs"
  depends_on :linux

  binary "neo-wrapper", target: "neo"

  preflight_steps do
    # Avoid version splitting inside the serialised steps.
    move "NEO-*.AppImage", "NEO.AppImage", source_glob: true
    set_permissions "NEO.AppImage", "+x"
    run "NEO.AppImage", args: ["--appimage-extract"], base: :staged_path, chdir: "."
    remove "NEO.AppImage"

    mkdir_p ".local/share/applications", base: :home
    mkdir_p ".local/share/icons", base: :home

    # AppRun (electron-builder) self-locates its AppDir via readlink, so the
    # extracted squashfs-root tree is fully self-contained. Keep the wrapper.
    write_file "neo-wrapper", <<~SH
      #!/bin/sh
      exec "{{staged_path}}/squashfs-root/AppRun" "$@"
    SH
    set_permissions "neo-wrapper", "0755"
  end

  postflight_steps do
    # Point the desktop entry at the Homebrew binary instead of "AppRun".
    # Keeps upstream's %U args, Keywords and StartupWMClass intact.
    run "/bin/sed", args:        ["-e", "s|^Exec=AppRun|Exec={{HOMEBREW_PREFIX}}/bin/neo|",
                                  "{{staged_path}}/squashfs-root/neo.desktop"],
                    stdout_path: "neo.desktop"
    copy "neo.desktop", ".local/share/applications/neo.desktop", target_base: :home
    copy "squashfs-root/usr/share/icons/hicolor/1024x1024/apps/neo.png",
         ".local/share/icons/neo.png", target_base: :home
  end

  uninstall_postflight_steps do
    remove ".local/share/applications/neo.desktop", base: :home
    remove ".local/share/icons/neo.png", base: :home
  end

  # Electron userData. The app sets its name at runtime; both plausible
  # names are listed — adjust after your first run if only one is created.
  zap trash: ["~/.config/neo", "~/.config/NEO"]
end
