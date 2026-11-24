# ii.yazi

Yazi preview adapter for `ii`. Requires the `ii` executable on `PATH` and a
terminal supporting Kitty Unicode image placeholders.

After publishing the standalone repository as OWNER/ii.yazi, install it:

```sh
ya pkg add OWNER/ii
```

During development, copy main.lua to
${YAZI_CONFIG_HOME:-$HOME/.config/yazi}/plugins/ii.yazi/main.lua.

Add preview rules to your Yazi configuration:

```toml
[plugin]
prepend_previewers = [
  { url = "*.{md,markdown,mdx,qmd,rmd,html,htm,ipynb,tex,latex,chem,mhchem,mmd,mermaid,dot,gv,svg,png,csv,tsv,vl,vega,vega-lite,plotly,zip,jar,whl,tar,tgz,tbz2,txz,tzst}", run = "ii" },
]
```

The adapter starts one CLI process per preview. The CLI starts the daemon when
needed and sends `PreviewFile` (IXPC command 5): visual row offset, file path,
geometry and theme. A bounded prepared-document cache avoids recompiling on scroll.
The response includes only the selected visual rows and their referenced images.
The CLI uses `--machine`; the adapter commits graphics on Yazi's main loop via
`ya.sync`, checking the current tab, URL, scroll offset and request generation.
Each graphic cell carries its row and column in the image, including when Yazi
redraws a fragment of a row. Every KGP continuation carries `q=2`.


`seek` uses Yazi's current offset and the requested number of visual rows. An
end-of-file request clamps to the last known row. Overlapping scroll frames reuse uploads by packet fingerprint, including large
charts. The adapter retains only fingerprints from the last published page.

Use `showcase/03.ipynb`, `08.csv` and `07.svg` to exercise notebook graphics, tables
and standalone images. Run `python3 showcase/checks/yazi.py --notebook` to check
both directions in a private Yazi session.
