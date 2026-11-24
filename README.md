# ii.yazi

Terminal graphical coprocessor preview adapter for [Yazi](https://github.com/sxyazi/yazi). Renders Markdown, LaTeX formulas, Mermaid diagrams, Vega/Plotly charts, SVGs, and Jupyter Notebooks inline using the Kitty Graphics Protocol (KGP) and Sixel.

Requires [ii](https://github.com/zx0r/ii#installation) on `PATH` and a terminal emulator supporting Kitty Graphics Protocol (Kitty, Ghostty, WezTerm).

---

## Features

- **Asynchronous Preloading**: Background worker pre-renders documents into memory via `prepend_preloaders` before cursor hover.
- **Thread-Safe Graphics Sync**: Atomic state synchronisation via `ya.sync` eliminates race conditions and scrolling stutter during fast pagination (`J` / `K`).
- **Terminal Grid Safety**: Enforces `ui.Wrap.NO` to prevent line-wrapping artifacts in tabular data and ASCII diagrams.
- **Multiplexer Pass-Through**: Automatically wraps Kitty escape codes in tmux DCS sequences (`\027Ptmux;...`).

---

## Installation

### Using Yazi Package Manager (Recommended)

```sh
ya pkg add zx0r/ii
```

### Manual Installation

```sh
git clone https://github.com/zx0r/ii.yazi.git ~/.config/yazi/plugins/ii.yazi
```

---

## Configuration

Add the preloader and previewer rules to `~/.config/yazi/yazi.toml`:

```toml
[plugin]
# Background preloader: caches rendered frames before cursor navigation
prepend_preloaders = [
  { url = "*.{md,markdown,mdx,qmd,rmd,ipynb,mmd,mermaid,dot,gv,svg,svgz,tex,latex,typ,typst,chem,mhchem,html,htm,csv,tsv,vl,vega,vega-lite,plotly,zip,jar,whl,tar,tgz,tbz2,txz,tzst}", run = "ii" },
]

# Tier 0 previewers: high-priority graphic coprocessor
prepend_previewers = [
  # Documents & scientific publications
  { url = "*.{md,markdown,mdx,qmd,rmd}", run = "ii" },
  { url = "*.ipynb",                     run = "ii" },
  { url = "*.{tex,latex,typ,typst}",     run = "ii" },

  # Vector diagrams, charts & layouts
  { url = "*.{mmd,mermaid,dot,gv,svg,svgz,vl,vega,vega-lite,plotly,chem,mhchem,html,htm}", run = "ii" },

  # Tabular datasets
  { url = "*.{csv,tsv}",                 run = "ii" },

  # Binary archive inspection
  { mime = "application/{*zip,tar,x-tar,gzip,x-bzip2,x-xz,zstd,java-archive}", run = "ii" },
  { url = "*.{zip,jar,whl,tar,tgz,tbz2,txz,tzst}", run = "ii" },
]
```

---

## Keybindings (Optional)

Configure smooth preview scrolling in `~/.config/yazi/keymap.toml`:

```toml
[mgr]
prepend_keymap = [
  { on = "J", run = "seek 5",  desc = "Scroll preview down 5 lines" },
  { on = "K", run = "seek -5", desc = "Scroll preview up 5 lines" },
]
```
