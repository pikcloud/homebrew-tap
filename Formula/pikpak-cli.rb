class PikpakCli < Formula
  desc "Cloud storage command-line tool for PikPak"
  homepage "https://mypikpak.com"
  version "0.5.1"

  on_macos do
    on_arm do
      url "https://download.mypikpak.com/cli/release/v#{version}/pikpak_darwin_arm64",
          using: :nounzip
      sha256 "d1ccf5eab4604501db97b1813c471adfdc5de57e4376bfb064378bbf3320558f"
    end
    on_intel do
      url "https://download.mypikpak.com/cli/release/v#{version}/pikpak_darwin_amd64",
          using: :nounzip
      sha256 "205e635a2368065b01afa4aeef26cc7217f6ec6fb3159aca9abf31ee4ef697ca"
    end
  end

  on_linux do
    on_arm do
      url "https://download.mypikpak.com/cli/release/v#{version}/pikpak_linux_arm64",
          using: :nounzip
      sha256 "34ff9e8fa5339476d4da5a561ad3c8bd0f023aff524171d065b6c8dd0bd4dfe1"
    end
    on_intel do
      url "https://download.mypikpak.com/cli/release/v#{version}/pikpak_linux_amd64",
          using: :nounzip
      sha256 "097af748484a88d4c8545e1a4df80e0b92e83f8f4f0aa3be9f99b4546c6f567a"
    end
  end

  def install
    bin.install Dir["pikpak_*"].first => "pikpak"
    # Standard Homebrew mode for a shipped binary; it blocks in-place writes but
    # not `pikpak update`, which renames a fresh file over this one (see caveats).
    (bin/"pikpak").chmod 0555
    # HOME is redirected so completion generation cannot touch a real ~/.pikpak.
    with_env(HOME: buildpath) do
      generate_completions_from_executable(bin/"pikpak", "completion")
    end
  end

  def caveats
    <<~CAVEATS
      Homebrew manages this `pikpak`, so upgrade with `brew upgrade pikpak-cli`.
      `pikpak update` still swaps the Cellar binary behind Homebrew's back and
      leaves the keg out of sync; `brew reinstall pikpak-cli` restores it.

      To teach a local AI coding agent the pikpak commands:
        pikpak skill install
    CAVEATS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/pikpak --version")
    assert_match "pikpak", shell_output("#{bin}/pikpak completion bash")
  end
end
