BIBLIOGRAPHY=Thesis.bib

LATEX=lualatex
BIBTEX=bibtex8

%.tex: %.md
	@pandoc -t LaTeX $< -o $@ --bibliography ${BIBLIOGRAPHY} --natbib --listings --chapter --smart

all: Thesis.pdf README.md

Thesis.pdf: $(wildcard *.tex) $(wildcard *.md) Makefile $(wildcard *.bib)
	@${LATEX}  Thesis
	@${BIBTEX} Thesis
	@${LATEX}  Thesis
	@${LATEX}  Thesis
	@${LATEX}  Thesis

Thesis.tex: 0-*-Abstract.tex 1-*-Intro.tex 2-*-Tech.tex 3-*-Components.tex 4-*-Execution.tex 5-*-Conclusion.tex 

README.md: $(wildcard *.md)
	cat 1-*Intro.md 2-*-Intro.md 3-*-Components.md 4-*-Execution.md 5-*-Conclusions.md | pandoc -t markdown -o $@ --bibliography ${BIBTEX} --smart --chapter

tidy:
	@trash 0-*-Abstract.tex
	@trash 1-*-Intro.tex
	@trash $(wildcard *.aux)
	@trash $(wildcard *.lof)
	@trash $(wildcard *.log)
	@trash $(wildcard *.lot)
	@trash $(wildcard *.out)
	@trash $(wildcard *.pdf)
	@trash $(wildcard *.toc)
	@trash $(wildcard *.bbl)
	@trash $(wildcard *.blg)
	@trash $(wildcard *.brf)

clean: tidy
	@trash Thesis.pdf
