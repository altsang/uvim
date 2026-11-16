cask "uvim-fork" do
  version "@VERSION@"
  sha256 "@SHA256@"

  url "https://github.com/altsang/uvim/releases/download/v#{version}/uvim-#{version}.zip"
  name "uvim (altsang fork)"
  desc "Vim's modal editing in any app's text fields, with clipboard sync and per-app settings"
  homepage "https://github.com/altsang/uvim"

  # The fork's builds carry no Sparkle feed: Homebrew is their only updater.
  depends_on macos: :sonoma
  conflicts_with cask: "uvim"

  app "uvim.app"

  # Signed with an Apple Development certificate and not notarized, so Gatekeeper would refuse
  # the downloaded copy; this tap is the owner's own, and the build is theirs.
  postflight do
    system_command "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "#{appdir}/uvim.app"]
  end

  uninstall quit: "io.github.celve.uvim"

  zap trash: [
    "~/Library/Application Support/uvim",
    "~/Library/Caches/io.github.celve.uvim",
    "~/Library/HTTPStorages/io.github.celve.uvim",
    "~/Library/HTTPStorages/io.github.celve.uvim.binarycookies",
    "~/Library/Preferences/io.github.celve.uvim.plist",
  ]
end
