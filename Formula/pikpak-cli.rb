class PikpakCli < Formula
  desc "Cloud storage command-line tool for PikPak"
  homepage "https://mypikpak.com"
  version "0.5.3"

  on_macos do
    on_arm do
      url "https://download.mypikpak.com/cli/release/v#{version}/pikpak_darwin_arm64",
          using: :nounzip
      sha256 "d86f0e9db1fbfc0f1340a2acdffe65711dc3e63a885b02d298070dd119ec66c7"
    end
    on_intel do
      url "https://download.mypikpak.com/cli/release/v#{version}/pikpak_darwin_amd64",
          using: :nounzip
      sha256 "b9b2f1522d3a83c0f480c8f546ba06dd3bb7fdfa987aa67f9f2ca39db5afd13b"
    end
  end

  on_linux do
    on_arm do
      url "https://download.mypikpak.com/cli/release/v#{version}/pikpak_linux_arm64",
          using: :nounzip
      sha256 "32a5866275908ff3fa758c12ed96994f0afddeb4f0fbfe057e7404799aed06a4"
    end
    on_intel do
      url "https://download.mypikpak.com/cli/release/v#{version}/pikpak_linux_amd64",
          using: :nounzip
      sha256 "bc0c3ed646372cca0986738e802cd816b43b2b0ac36cd15231faffb139c095dc"
    end
  end

  # A referral code rides along with the install:
  #   brew install pikcloud/tap/pikpak-cli --with-affiliate-<code>
  #   HOMEBREW_PIKPAK_AFFILIATE=<code> brew install pikcloud/tap/pikpak-cli
  # Homebrew rejects any flag a formula did not declare and an option name is
  # fixed at load time, so the code itself has to become part of the declared
  # name -- hence reading the command line here. Plain `PIKPAK_AFFILIATE` is
  # not usable: `brew` drops environment variables without a `HOMEBREW_`
  # prefix before a formula ever runs. `brew style` objects to both lines
  # below; they are homebrew/core policy (no `option`, no `ARGV`) and core
  # has no way to express a flag that carries a value.
  ARGV.each do |arg|
    next unless arg.start_with?("--with-affiliate-")

    option arg.delete_prefix("--"), "Record this referral code in ~/.pikpak/affiliate"
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
    # The build sandbox denies every write to $HOME, so the code is staged in
    # the keg here and copied out by `caveats`, which runs unsandboxed.
    code = affiliate_code
    (pkgshare/"affiliate").write(code) if code
  end

  # The code becomes a file's contents and is sent to the API, so keep it to
  # the characters a referral code can actually contain.
  def affiliate_code
    flag = build.used_options.map(&:to_s).find { |opt| opt.start_with?("--with-affiliate-") }
    code = flag&.delete_prefix("--with-affiliate-").presence ||
           ENV["HOMEBREW_PIKPAK_AFFILIATE"].presence
    code if code&.match?(/\A[A-Za-z0-9_-]{1,64}\z/)
  end

  # `caveats` also runs for `brew info`, so this only ever reports the state it
  # finds, creating `~/.pikpak/affiliate` when no code has been recorded yet and
  # never overwriting a code the user or an earlier install already chose.
  def record_affiliate_code
    staged = pkgshare/"affiliate"
    return unless staged.file?

    target = Pathname(Dir.home)/".pikpak/affiliate"
    unless target.exist?
      target.dirname.mkpath
      target.write(staged.read)
      target.chmod 0600
    end
    "Referral code #{target.read.chomp} is recorded in #{target}."
  rescue SystemCallError => e
    <<~FAILED.chomp
      Could not record the referral code (#{e.message}); to do it by hand:
        mkdir -p ~/.pikpak && echo #{staged.read.chomp} > ~/.pikpak/affiliate
    FAILED
  end

  def caveats
    notes = [<<~CAVEATS.chomp]
      Homebrew manages this `pikpak`, so upgrade with `brew upgrade pikpak-cli`.
      `pikpak update` still swaps the Cellar binary behind Homebrew's back and
      leaves the keg out of sync; `brew reinstall pikpak-cli` restores it.

      To teach a local AI coding agent the pikpak commands:
        pikpak skill install
    CAVEATS
    notes << record_affiliate_code
    notes.compact.join("\n\n")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/pikpak --version")
    assert_match "pikpak", shell_output("#{bin}/pikpak completion bash")
  end
end
