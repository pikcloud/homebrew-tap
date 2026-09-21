# homebrew-tap

Homebrew tap for [pikpak-cli](https://mypikpak.com) — the PikPak cloud storage
command-line tool.

## Install

```sh
brew install pikcloud/tap/pikpak-cli
```

Or tap first:

```sh
brew tap pikcloud/tap
brew install pikpak-cli
```

The formula is `pikpak-cli` (the binary it installs is `pikpak`); `pikpak`
alone is already taken by the official `homebrew/cask/pikpak` desktop app.

Upgrade:

```sh
brew upgrade pikpak-cli
```

Bash/zsh/fish completions are installed with the formula.

## Referral code

An install can carry a referral code, which lands in `~/.pikpak/affiliate`:

```sh
brew install pikcloud/tap/pikpak-cli --with-affiliate-<code>
```

The flag name has to contain the code because Homebrew rejects any flag a
formula did not declare, and a formula declares its options when it is loaded.
For callers that cannot append a flag — a piped script, a wrapper — the same
code goes in the environment (the `HOMEBREW_` prefix is required; `brew` drops
other variables before a formula runs):

```sh
HOMEBREW_PIKPAK_AFFILIATE=<code> brew install pikcloud/tap/pikpak-cli
```

A code is accepted only as `[A-Za-z0-9_-]{1,64}`, and an existing
`~/.pikpak/affiliate` is never overwritten, so the first code recorded on a
machine stays. The file is written from `caveats` rather than `install`,
because the build sandbox denies every write to `$HOME`.

Two consequences worth knowing:

- `brew install -q` suppresses caveats, so it also skips writing the file.
- The flag is stored in the install receipt but Homebrew drops unknown options
  on `brew upgrade`, so a later upgrade neither fails nor rewrites the code.

> Use `brew upgrade`, not `pikpak update`. The self-updater renames a freshly
> downloaded binary over the Cellar file, which succeeds and then leaves the keg
> out of sync with Homebrew's manifest. `brew reinstall pikpak-cli` restores it.

## Releasing

`Formula/pikpak-cli.rb` is generated from a published release — the version,
URLs, and checksums all come from `checksums.txt` next to the binaries:

```sh
scripts/update-formula.sh          # follow the release API's current tag
scripts/update-formula.sh v0.5.0   # pin a tag
```

The script refuses to write a formula whose assets are missing or whose
checksums are malformed, and exits without a change when the formula already
matches the release, so CI can commit only on a real update.

`.github/workflows/update-formula.yml` runs it on a schedule and on manual
dispatch, committing any change. Nothing here needs hand-editing; fix the
release pipeline in
[pikpak-cli](https://gitlab.pikcloud.net/server/pikpak-cli) instead.

## Release layout this tap depends on

```
https://download.mypikpak.com/cli/release/<tag>/
  pikpak_darwin_arm64
  pikpak_darwin_amd64
  pikpak_linux_arm64
  pikpak_linux_amd64
  checksums.txt        # "<sha256>  <filename>" per line
```

The current tag is read from
`https://config.mypikpak.com/config/v1/command_line?client=global`
(`values.command_line.tag_name`) — the same endpoint `pikpak update` uses.
