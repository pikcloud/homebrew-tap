#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Regenerate Formula/pikpak-cli.rb from a published pikpak-cli release.
#
#   scripts/update-formula.sh            # follow the release API's current tag
#   scripts/update-formula.sh v0.5.0     # pin a tag
#
# Environment overrides:
#   PIKPAK_UPDATE_API_URL   release metadata endpoint
#   PIKPAK_RELEASE_BASE     release directory base (…/cli/release)
#
# Exits 0 without touching the formula when it already matches the release, so
# CI can commit only on a real change.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

API_URL="${PIKPAK_UPDATE_API_URL:-https://config.mypikpak.com/config/v1/command_line?client=global}"
RELEASE_BASE="${PIKPAK_RELEASE_BASE:-https://download.mypikpak.com/cli/release}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
formula="${repo_root}/Formula/pikpak-cli.rb"

die() {
  echo "error: $*" >&2
  exit 1
}

command -v curl >/dev/null || die "curl is required"

# ── Resolve the tag ──────────────────────────────────────────────────────────
tag="${1:-}"
if [[ -z "${tag}" ]]
then
  json="$(curl -fsSL "${API_URL}")" || die "failed to fetch ${API_URL}"
  # { "values": { "command_line": { "tag_name": "v0.5.0", "assets": [...] } } }
  tag="$(printf '%s' "${json}" | tr -d '\n\r' |
    sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  [[ -n "${tag}" ]] && [[ "${tag}" != "null" ]] || die "no tag_name in API response"
fi
case "${tag}" in
  v*) ;;
  *) tag="v${tag}" ;;
esac
version="${tag#v}"

# ── Checksums are authoritative; the formula never hashes downloads itself ───
checksums="$(curl -fsSL "${RELEASE_BASE}/${tag}/checksums.txt")" ||
  die "no checksums.txt for ${tag} under ${RELEASE_BASE}"

sha_for() {
  local name="$1" sum
  sum="$(printf '%s\n' "${checksums}" | awk -v n="${name}" '$2 == n { print $1; exit }')"
  [[ ${#sum} -eq 64 ]] || die "missing or malformed sha256 for ${name} in ${tag}/checksums.txt"
  printf '%s' "${sum}"
}

darwin_arm64="$(sha_for pikpak_darwin_arm64)"
darwin_amd64="$(sha_for pikpak_darwin_amd64)"
linux_arm64="$(sha_for pikpak_linux_arm64)"
linux_amd64="$(sha_for pikpak_linux_amd64)"

# A checksum line for an asset that was never uploaded would produce a formula
# that only fails at `brew install` time, so confirm each URL really serves.
for asset in pikpak_darwin_arm64 pikpak_darwin_amd64 pikpak_linux_arm64 pikpak_linux_amd64
do
  curl -fsSI "${RELEASE_BASE}/${tag}/${asset}" >/dev/null ||
    die "asset not published: ${RELEASE_BASE}/${tag}/${asset}"
done

# ── Render ───────────────────────────────────────────────────────────────────
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

cat >"${tmp}" <<EOF
class PikpakCli < Formula
  desc "Cloud storage command-line tool for PikPak"
  homepage "https://mypikpak.com"
  version "${version}"

  on_macos do
    on_arm do
      url "${RELEASE_BASE}/v#{version}/pikpak_darwin_arm64",
          using: :nounzip
      sha256 "${darwin_arm64}"
    end
    on_intel do
      url "${RELEASE_BASE}/v#{version}/pikpak_darwin_amd64",
          using: :nounzip
      sha256 "${darwin_amd64}"
    end
  end

  on_linux do
    on_arm do
      url "${RELEASE_BASE}/v#{version}/pikpak_linux_arm64",
          using: :nounzip
      sha256 "${linux_arm64}"
    end
    on_intel do
      url "${RELEASE_BASE}/v#{version}/pikpak_linux_amd64",
          using: :nounzip
      sha256 "${linux_amd64}"
    end
  end

  def install
    bin.install Dir["pikpak_*"].first => "pikpak"
    # Standard Homebrew mode for a shipped binary; it blocks in-place writes but
    # not \`pikpak update\`, which renames a fresh file over this one (see caveats).
    (bin/"pikpak").chmod 0555
    # HOME is redirected so completion generation cannot touch a real ~/.pikpak.
    with_env(HOME: buildpath) do
      generate_completions_from_executable(bin/"pikpak", "completion")
    end
  end

  def caveats
    <<~CAVEATS
      Homebrew manages this \`pikpak\`, so upgrade with \`brew upgrade pikpak-cli\`.
      \`pikpak update\` still swaps the Cellar binary behind Homebrew's back and
      leaves the keg out of sync; \`brew reinstall pikpak-cli\` restores it.

      To teach a local AI coding agent the pikpak commands:
        pikpak skill install
    CAVEATS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/pikpak --version")
    assert_match "pikpak", shell_output("#{bin}/pikpak completion bash")
  end
end
EOF

if [[ -f "${formula}" ]] && cmp -s "${tmp}" "${formula}"
then
  echo "Formula/pikpak-cli.rb already at ${tag}; nothing to do"
  exit 0
fi

mkdir -p "$(dirname "${formula}")"
mv "${tmp}" "${formula}"
# mktemp yields 0600; `brew style` rejects a formula that is not world-readable.
chmod 644 "${formula}"
trap - EXIT
echo "Formula/pikpak-cli.rb updated to ${tag}"
