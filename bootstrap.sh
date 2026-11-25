#!/bin/bash
set -euo pipefail

usage() {
  printf 'Usage: %s [--check]\n' "$0"
}

check_only=0
case "${1:-}" in
  '') ;;
  --check) check_only=1 ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
if (( $# > 1 )); then usage >&2; exit 2; fi

fail() {
  printf 'Brewprint: %s\n' "$*" >&2
  exit 1
}

[[ "$(uname -s)" == Darwin ]] || fail 'Brewprint requires macOS.'
[[ "$(uname -m)" == arm64 ]] || fail 'Run Brewprint in a native Apple silicon terminal.'
macos_version=$(sw_vers -productVersion)
(( ${macos_version%%.*} >= 15 )) || fail 'Brewprint requires macOS 15 or later.'
(( EUID != 0 )) || fail 'Run Brewprint as your own user, without sudo.'

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
brewfile="$repo_dir/Brewfile"
bash_profile="$HOME/.config/brewprint/bashrc"
iterm_profile="$HOME/Library/Application Support/iTerm2/DynamicProfiles/brewprint.json"
brew_bin=/opt/homebrew/bin/brew
bashrc="$HOME/.bashrc"
login_file="$HOME/.bash_profile"
for candidate in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
  if [[ -f "$candidate" && -r "$candidate" ]]; then
    login_file="$candidate"
    break
  fi
done
bashrc_line='[ ! -r "$HOME/.config/brewprint/bashrc" ] || . "$HOME/.config/brewprint/bashrc" # Brewprint'
login_line='[ ! -r "$HOME/.bashrc" ] || . "$HOME/.bashrc" # Brewprint'

export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1
export NONINTERACTIVE=1 SUDO_ASKPASS=/usr/bin/false

has_line() {
  [[ -f "$1" ]] && grep -Fxq -- "$2" "$1"
}

bundle_check() {
  "$brew_bin" bundle check --no-upgrade --file "$brewfile" "$@"
}

if (( check_only )); then
  pending=0
  if [[ ! -x "$brew_bin" ]]; then
    printf '%s\n' 'Homebrew and the packages in Brewfile need installation.'
    pending=1
  elif ! bundle_check --verbose; then
    pending=1
  fi
  if ! cmp -s "$repo_dir/dotfiles/bashrc" "$bash_profile" ||
     ! has_line "$bashrc" "$bashrc_line" ||
     ! has_line "$login_file" "$login_line"; then
    printf '%s\n' 'Bash profile needs setup or an update.'
    pending=1
  fi
  if ! cmp -s "$repo_dir/config/iterm2/brewprint.json" "$iterm_profile"; then
    printf '%s\n' 'iTerm2 profile needs setup or an update.'
    pending=1
  fi
  if (( ! pending )); then printf '%s\n' 'Brewprint is up to date.'; fi
  exit "$pending"
fi

log_dir="$HOME/Library/Logs/Brewprint"
mkdir -p "$log_dir"
log_file=$(mktemp "$log_dir/setup.XXXXXXXX")
printf 'Setup log: %s\n' "$log_file"
exec > >(tee -a "$log_file") 2>&1

stage='checking installed packages'
sudo_keepalive=
installer=
finish() {
  local status=$?
  if [[ -n "$sudo_keepalive" ]]; then kill "$sudo_keepalive" 2>/dev/null || true; fi
  if [[ -n "$installer" ]]; then rm -f "$installer"; fi
  if (( status )); then
    printf 'Brewprint stopped while %s. See %s. Rerun after resolving the issue.\n' "$stage" "$log_file" >&2
  fi
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ ! -x "$brew_bin" ]] || ! bundle_check --quiet; then
  stage='authorizing installation'
  if ! /usr/bin/sudo -n -v 2>/dev/null; then
    [[ -t 0 ]] || fail 'Admin authorization is required. Start setup from a terminal.'
    printf '%s\n' 'Authorize installation now. Setup will continue unattended where macOS allows.'
    /usr/bin/sudo -v || fail 'Admin authorization failed.'
  fi
  # Refresh the terminal's sudo timestamp while downloads and installs run.
  (while sleep 45; do /usr/bin/sudo -n -v || exit; done) </dev/null >/dev/null 2>&1 &
  sudo_keepalive=$!

  if [[ ! -x "$brew_bin" ]]; then
    stage='installing Homebrew'
    installer=$(mktemp "${TMPDIR:-/tmp}/brewprint-install.XXXXXXXX")
    /usr/bin/curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"
    /bin/bash "$installer" </dev/null
    [[ -x "$brew_bin" ]] || fail 'Homebrew installer finished without creating brew.'
  fi

  stage='installing packages and apps'
  "$brew_bin" bundle install --no-upgrade --file "$brewfile" </dev/null
fi

stage='verifying packages and apps'
bundle_check --verbose

stage='installing the Bash and iTerm2 profiles'
mkdir -p "$(dirname "$bash_profile")" "$(dirname "$iterm_profile")"
if ! cmp -s "$repo_dir/dotfiles/bashrc" "$bash_profile"; then
  install -m 644 "$repo_dir/dotfiles/bashrc" "$bash_profile"
fi
if ! has_line "$bashrc" "$bashrc_line"; then
  printf '\n%s\n' "$bashrc_line" >> "$bashrc"
fi
if ! has_line "$login_file" "$login_line"; then
  printf '\n%s\n' "$login_line" >> "$login_file"
fi
if ! cmp -s "$repo_dir/config/iterm2/brewprint.json" "$iterm_profile"; then
  install -m 644 "$repo_dir/config/iterm2/brewprint.json" "$iterm_profile"
fi

stage='verifying the Bash profile'
/bin/bash --noprofile --rcfile "$bash_profile" -ic 'alias gst >/dev/null && mise --version' </dev/null
printf 'Setup complete. Open the Brewprint profile in iTerm2. Apps may ask for sign-in or approval on first launch.\nLog: %s\n' "$log_file"
