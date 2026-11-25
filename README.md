# Brewprint

Set up an Apple silicon Mac running macOS 15 or later with Homebrew apps and command-line tools, an iTerm2 profile, and Bash configured for mise.

## Set up a Mac

Download or clone the repository, open a native terminal, and run this from the repository directory as your normal user:

```sh
./bootstrap.sh
```

If packages need installation, the script may request admin authorization up front. Homebrew runs unattended after that where macOS permits. Open **Profiles → Brewprint** in iTerm2 to start a session in the system Bash. The account's login shell and any existing iTerm2 default are preserved. Apps may require sign-in or macOS approval when you first open them.

Use `./bootstrap.sh --check` to see what setup is pending without installing anything or changing your profiles. It exits with status 0 when everything is in place and 1 when work is pending.

## Customize

- **Apps and command-line tools** are listed in [Brewfile](Brewfile). Homebrew resolves the dependencies. Rerunning setup installs missing entries and skips routine upgrades. Removing an entry does not uninstall it.
- **Bash aliases, prompt, and PATH** live in [dotfiles/bashrc](dotfiles/bashrc). Rerun setup after editing it, then open a new Bash session. Keep personal settings in your own Bash startup files.
- **iTerm2 colors, fonts, and profile shortcuts** live in [config/iterm2/brewprint.json](config/iterm2/brewprint.json). Setup installs it as a Dynamic Profile based on the original Mac's iTerm2 settings. App-wide preferences stay in iTerm2.
- **Development tools and runtimes** belong in each project's `mise.toml` or `.tool-versions`. Run `mise install` in that project. Brewprint activates mise in Bash. Global runtimes, database servers, and macOS preference changes are outside the default setup.

## Recover a failed run

The script prints its log path under `~/Library/Logs/Brewprint/`. Check the reported stage, resolve the issue, and run `./bootstrap.sh` again. If Command Line Tools could not be installed automatically, run `xcode-select --install` and finish the macOS installer before retrying. If Homebrew reports a conflict with an app installed by hand, review the existing app before moving it out of the way and retrying.

## License

Brewprint is distributed under the [MIT License](LICENSE).
