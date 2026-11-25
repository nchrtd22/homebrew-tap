cask "tidemark" do
  os linux: "linux"

  version "0.6.5"
  sha256 "8ddce0ca47a8039dc785a9474ab801227b00b467a5d1b7754eec67b2399e92a5"

  # Vendor tags are "v"-prefixed (github_latest strips the v).
  url "https://github.com/zbndev/tidemark/releases/download/v#{version}/Tidemark-v#{version}.deb"
  name "Tidemark"
  desc "Tracks AI provider rate-limit quotas from the tray"
  homepage "https://github.com/zbndev/tidemark"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :x86_64
  depends_on formula: "binutils"   # provides `ar` for the Deb unpack
  depends_on :linux

  # Vendor artifact is a Deb: brew has no Deb strategy (and mis-sniffs zst
  # members as zstd archives), so stage it as-is and unpack in preflight.
  container type: :naked

  # No wrapper needed — three plain native binaries, self-contained
  # against system libs only (GUI: libEGL/libfontconfig; daemon: libsqlite3;
  # no webkit, no toolkit bundling). Direct symlinks survive version bumps.
  binary "usr/bin/tidemark",    target: "tidemark"
  binary "usr/bin/tidemarkctl", target: "tidemarkctl"
  binary "usr/bin/tidemarkd",    target: "tidemarkd"

  preflight_steps do
    # Deb unpack (Route B, QualCoder/espanso pattern):
    #   ar x Tidemark.deb            -> control.tar.xz + data.tar.xz
    #   /usr/bin/tar -xf data.tar.xz -> usr/ + etc/ trees
    # NB: this Deb's members are XZ, not zst (unlike QualCoder's) — plain
    # `tar -xf` autodetects it; adding --zstd here would fail.
    move "Tidemark-*.deb", "Tidemark.deb", source_glob: true
    run "{{HOMEBREW_PREFIX}}/opt/binutils/bin/ar", args: ["x", "Tidemark.deb"],
                                                    base: :staged_path, chdir: "."
    remove "control.tar.xz", base: :staged_path
    remove "debian-binary", base: :staged_path
    # chdir is load-bearing: without it tar extracts into brew's own cwd
    # (verified the hard way on QualCoder 4.0).
    run "/usr/bin/tar", args: ["-xf", "data.tar.xz"], base: :staged_path, chdir: "."
    remove "data.tar.xz", base: :staged_path
    remove "Tidemark.deb", base: :staged_path

    mkdir_p ".local/share/applications", base: :home
    mkdir_p ".local/share/icons", base: :home
    # Daemon plumbing mirrored from the vendor's system dirs into XDG userspace:
    mkdir_p ".local/share/systemd/user", base: :home
    mkdir_p ".local/share/dbus-1/services", base: :home
    mkdir_p ".config/autostart", base: :home
  end

  postflight_steps do
    # 1) Applications entry: point the bare `Exec=tidemark` at our binary.
    run "/bin/sed",
        args: ["-e", "s|^Exec=tidemark$|Exec={{HOMEBREW_PREFIX}}/bin/tidemark|",
               "{{staged_path}}/usr/share/applications/io.github.zbndev.Tidemark.desktop"],
        stdout_path: "io.github.zbndev.Tidemark.desktop"
    copy "io.github.zbndev.Tidemark.desktop",
         ".local/share/applications/io.github.zbndev.Tidemark.desktop", target_base: :home

    # 2) XDG autostart (vendor ships it in /etc/xdg/autostart; user-space
    #    equivalent lives in ~/.config/autostart): tray resident at login.
    run "/bin/sed",
        args: ["-e", "s|^Exec=tidemark --background$|Exec={{HOMEBREW_PREFIX}}/bin/tidemark --background|",
               "{{staged_path}}/etc/xdg/autostart/io.github.zbndev.Tidemark.desktop"],
        stdout_path: "tidemark-autostart.desktop"
    copy "tidemark-autostart.desktop",
         ".config/autostart/io.github.zbndev.Tidemark.desktop", target_base: :home

    # 3) systemd user unit: ExecStart repointed from /usr/bin to the brew
    #    symlink, so the unit NEVER needs re-patching on version bumps.
    #    Rest stays vendor-authored (After/PartOf=graphical-session.target,
    #    Type=dbus, WantedBy=default.target). Enabling stays manual — the
    #    cask never runs systemctl (no user session in CI).
    run "/bin/sed",
        args: ["-e", "s|^ExecStart=/usr/bin/tidemarkd|ExecStart={{HOMEBREW_PREFIX}}/bin/tidemarkd|",
               "{{staged_path}}/usr/lib/systemd/user/tidemarkd.service"],
        stdout_path: "tidemarkd.service"
    copy "tidemarkd.service", ".local/share/systemd/user/tidemarkd.service", target_base: :home

    # 4) D-Bus activation: same Exec swap; SystemdService= stays as-is, and
    #    dbus-broker watches ~/.local/share/dbus-1/services live (no reload).
    run "/bin/sed",
        args: ["-e", "s|^Exec=/usr/bin/tidemarkd|Exec={{HOMEBREW_PREFIX}}/bin/tidemarkd|",
               "{{staged_path}}/usr/share/dbus-1/services/io.github.zbndev.Tidemark.Daemon.service"],
        stdout_path: "io.github.zbndev.Tidemark.Daemon.service"
    copy "io.github.zbndev.Tidemark.Daemon.service",
         ".local/share/dbus-1/services/io.github.zbndev.Tidemark.Daemon.service", target_base: :home

    # 5) Icon (desktop file references it via Icon=io.github.zbndev.Tidemark).
    copy "usr/share/icons/hicolor/512x512/apps/io.github.zbndev.Tidemark.png",
         ".local/share/icons/io.github.zbndev.Tidemark.png", target_base: :home
  end

  uninstall_postflight_steps do
    remove ".local/share/applications/io.github.zbndev.Tidemark.desktop", base: :home
    remove ".config/autostart/io.github.zbndev.Tidemark.desktop", base: :home
    remove ".local/share/systemd/user/tidemarkd.service", base: :home
    remove ".local/share/dbus-1/services/io.github.zbndev.Tidemark.Daemon.service", base: :home
    remove ".local/share/icons/io.github.zbndev.Tidemark.png", base: :home
  end

  # Preferences live in the Secret Service (keyring), keyed by schema
  # io.github.zbndev.Tidemark.ProviderKey — NOT on disk, so zap cannot reach
  # them as paths. To also clear stored provider keys:
  #   secret-tool clear xdg:schema io.github.zbndev.Tidemark.ProviderKey
  # On-disk paths verified at first launch (no cache dir is created).
  zap trash: ["~/.config/tidemark", "~/.local/share/tidemark"]
end
