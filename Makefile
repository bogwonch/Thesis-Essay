all: Thesis.md Thesis.template
	pandoc -t latex Thesis.md -o Thesis.tex \
		--standalone                          \
		--toc                                 \
		--smart                               \
		--listings                            \
		--chapter                             \
		--bibliography=Thesis.bib             \
		--biblatex

	pdflatex Thesis
	bibtex Thesis
	pdflatex Thesis
	pdflatex Thesis


clean:
	rubber --clean Thesis
	rm Thesis.tex
