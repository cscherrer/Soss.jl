# JuliaConSubmission

[![Build Status](https://travis-ci.org/JuliaCon/JuliaConSubmission.jl.svg?branch=master)](https://travis-ci.org/JuliaCon/JuliaConSubmission.jl)

This repository is an example for a proceeding submission at JuliaCon 2019.
Feel free to use the template in `/paper` to prepare yours.
For more information, go to the [proceedings website](https://proceedings.juliacon.org).

## Paper dependencies

The document can be built locally, the following dependencies need to be
installed:
- Ruby
- latexmk

## Build process

Build the paper using:
```
$ latexmk -bibtex -pdf paper.tex
```

Clean up temporary files using:
```
$ latexmk -c
```

## Paper metadata

**IMPORTANT**
Some information for building the document (such as the title and keywords)
is provided through the `paper.yml` file and not through the usual `\title`
command. Respecting the process is important to avoid build errors when
submitting your work.

## Get from OverLeaf

The paper folder can be downloaded from [OverLeaf](https://www.overleaf.com/read/dqjbrhqxjpwq).
The build process has been tested on the platform for users who cannot build it locally.
