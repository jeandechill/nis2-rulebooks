pandoc ../rulebooks/operational-guidance-incident-handling.md --columns=10  --pdf-engine=xelatex -V colorlinks=true -V linkcolor=blue  -V urlcolor=red  -V toccolor=gray --number-sections --toc -V toc-own-page=true -V footnotes-pretty=true -V table-use-row-color=true --template eisvogel  -o output.pdf 
cp output.pdf ../rulebooks/operational-guidance-incident-handling.pdf
