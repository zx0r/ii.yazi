# ii.yazi

Preview documents and notebooks in Yazi. Install [ii](https://github.com/zx0r/ii#installation) first and put it on `PATH`. Use a terminal with Kitty graphics support.

## Installation

```sh
ya pkg add zx0r/ii
```

Add this rule to your Yazi previewers in `yazi.toml`:

```toml
[plugin]
prepend_previewers = [
  { url = "*.{md,markdown,mdx,qmd,rmd,ipynb,tex,svg,mmd,dot,csv,tsv}", run = "ii" },
]
```
