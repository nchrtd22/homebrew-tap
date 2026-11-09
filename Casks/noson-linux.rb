cask "noson-linux" do
  os linux: "linux"

  version "5.7.7"
  sha256 "20eb4155f01153ced8b0e705f3fb5970d27e432f4fed15e55e34f3c209a319a6"

  url "https://github.com/janbar/noson-app/releases/download/#{version}/noson-#{version}-x86_64.AppImage"
  name "Noson"
  desc "Fast and smart SONOS controller for Unix platforms"
  homepage "https://github.com/janbar/noson-app"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :x86_64
  depends_on formula: "squashfs"
  depends_on :linux

  binary "noson-wrapper", target: "noson"
  binary "squashfs-root/usr/bin/noson-cli", target: "noson-cli"

  preflight_steps do
    # Avoid version splitting inside the serialised steps.
    move "noson-*-x86_64.AppImage", "noson.AppImage", source_glob: true
    set_permissions "noson.AppImage", "+x"
    run "noson.AppImage", args: ["--appimage-extract"], base: :staged_path, chdir: "."
    remove "noson.AppImage"

    mkdir_p ".local/share/applications", base: :home
    mkdir_p ".local/share/icons", base: :home

    # AppRun is a symlink to usr/bin/noson-app, and usr/bin/qt.conf makes the
    # binary resolve plugins/qml/translations relative to itself, so the
    # extracted squashfs-root tree is fully self-contained. Keep the wrapper.
    write_file "noson-wrapper", <<~SH
      #!/bin/sh
      exec "{{staged_path}}/squashfs-root/AppRun" "$@"
    SH
    set_permissions "noson-wrapper", "0755"
  end

  postflight_steps do
    # Patch the desktop entry so it launches the Homebrew binary, not "noson-app" via PATH.
    run "/bin/sed", args:        ["-e", "s|^Exec=.*|Exec={{HOMEBREW_PREFIX}}/bin/noson|",
                                  "{{staged_path}}/squashfs-root/io.github.janbar.noson.desktop"],
                    stdout_path: "io.github.janbar.noson.desktop"
    copy "io.github.janbar.noson.desktop", ".local/share/applications/io.github.janbar.noson.desktop",
         target_base: :home
    copy "squashfs-root/usr/share/icons/hicolor/64x64/apps/noson.png",
         ".local/share/icons/noson.png", target_base: :home
  end

  uninstall_postflight_steps do
    remove ".local/share/applications/io.github.janbar.noson.desktop", base: :home
    remove ".local/share/icons/noson.png", base: :home
  end

  # Noson keeps its settings under ~/.config (Qt QStandardPaths).
  zap trash: "~/.config/noson"
end
