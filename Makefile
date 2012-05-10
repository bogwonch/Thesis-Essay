latex=pdflatex

all: Thesis.md 

	pandoc -t latex Thesis.md -o Thesis.tex \
		--standalone                          \
		--toc                                 \
		--listings                            \
		--chapter                             \
		--bibliography=Thesis.bib             \
		--biblatex                            \
		--template=default.latex              \
		-V fontsize=10pt                      \
		-V mainfont="Fanwood Text"

	${latex} Thesis
	bibtex Thesis
	${latex} Thesis
	${latex} Thesis


clean:
	rubber --clean Thesis
	rm Thesis.tex
