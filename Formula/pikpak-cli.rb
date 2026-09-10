class PikpakCli < Formula
  desc "Cloud storage command-line tool for PikPak"
  homepage "https://mypikpak.com"
  version "0.5.0"

  on_macos do
    on_arm do
      url "https://download.mypikpak.com/cli/release/v#{version}/pikpak_darwin_arm64",
          using: :nounzip
      sha256 "efd1732f56f41c01ab7c785aae85057e7e4a48f44551530f76147b7c73581ea9"
    end
    on_intel do
      url "https://download.mypikpak.com/cli/release/v#{version}/pikpak_darwin_amd64",
          using: :nounzip
      sha256 "6c13a78c9961aae2a5b4bc4a9fea5606e4de02f6251996ae6148e342aa063772"
    end
  end

  on_linux do
    on_arm do
      url "https://download.mypikpak.com/cli/release/v#{version}/pikpak_linux_arm64",
          using: :nounzip
      sha256 "79cf1c5182eb228622b2db7bf4da438e236db33f6bce624291fb4e54100ebfb7"
    end
    on_intel do
      url "https://download.mypikpak.com/cli/release/v#{version}/pikpak_linux_amd64",
          using: :nounzip
      sha256 "515e094e4504699a6d6e725dffbcc35d975598af7e0bb5926eda945acce41b58"
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
