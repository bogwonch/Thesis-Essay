BIBLIOGRAPHY=Thesis.bib

LATEX=pdflatex
BIBTEX=bibtex8

%.tex: %.md
	@pandoc -t LaTeX $< -o $@ --bibliography ${BIBLIOGRAPHY} --natbib --listings --chapter --smart


Thesis.pdf: $(wildcard *.tex) $(wildcard *.md) Makefile $(wildcard *.bib)
	@${LATEX}  Thesis
	@${BIBTEX} Thesis
	@${LATEX}  Thesis
	@${LATEX}  Thesis
	@${LATEX}  Thesis

Thesis.tex: 0-*-Abstract.tex 1-*-Intro.tex 2-*-Tech.tex 3-*-Components.tex 4-*-Execution.tex 5-*-Conclusion.tex 

tidy:
	@trash 0-*-Abstract.tex
	@trash 1-*-Intro.tex
	@trash 1-1-Intro-What.tex
	@trash 1-2-Intro-Why.tex
	@trash 1-3-Intro-Who.tex
	@trash 1-4-Intro-Summary.tex
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
