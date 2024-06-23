# CV

Generate Markdown and PDF CVs from TOML.

## Dependencies

- [`yq`](https://mikefarah.gitbook.io/yq)
- [`pandoc`](https://pandoc.org/)
- [`latexmk`](https://mg.readthedocs.io/latexmk.html), XeLaTeX, fonts and packages (see [template.tex](src/cmd/cv-tex/template.tex))

## Usage

```console
$ cv.sh cv.toml -l en -c cv.config.toml
$ open cv.md cv.pdf
```
