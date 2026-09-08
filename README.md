<p align="center">
  <a href="https://github.com/lupaxa-developers-toolbox">
    <img src="https://raw.githubusercontent.com/the-lupaxa-project/brand-assets/master/logos/organisations/developers-toolbox/readme-logo.png" alt="Developers Toolbox" />
  </a>
</p>

<h1 align="center">Bash Colour Testcard</h1>

A terminal colour testcard for Bash. It detects how many colours the terminal
supports, sizes the grid to the current window, and shows each code as a
swatch.

## Use

```bash
./src/bash-colour-testcard.sh        # simple mode (default)
./src/bash-colour-testcard.sh -s     # simple swatches
./src/bash-colour-testcard.sh -c     # complete foreground × background
./src/bash-colour-testcard.sh -n     # print the supported colour count
./src/bash-colour-testcard.sh -t     # interactive test of two colour codes
./src/bash-colour-testcard.sh -m 16  # cap the display at N colours
./src/bash-colour-testcard.sh -V     # print the version
```

`-c`, `-n`, `-s`, and `-t` are exclusive. Colour codes are `0` through
`ncolors-1`. The terminal must support at least 8 colours. Complete mode
without `-m` caps at 16 colours when the terminal has more.

Display modes need a TTY. Set `FORCE_COLOR=1` to draw in a pipe. `NO_COLOR`
disables the swatch display (count, help, and version still work).

## Development

```bash
make init   # first-time makefile-skills checkout
make check  # bash -n, ShellCheck, and tests/run_all.sh
```

<a href="https://github.com/the-lupaxa-project">
  <img src="https://raw.githubusercontent.com/the-lupaxa-project/brand-assets/master/logos/components/footer-for-child-orgs.svg" alt="The Lupaxa Project Footer" width="100%" />
</a>
