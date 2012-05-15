latex=pdflatex

all: Thesis.md 

	#pandoc -t latex Thesis.md -o Thesis.tex \
	#	--standalone                          \
	#	--toc                                 \
	#	--chapter                             \
	#	--listings                            \
	#	--bibliography=Thesis.bib             \
	#	--biblatex                            \
	#	--template=default.latex              \
	#	-V fontsize=12pt                      

	${latex} Thesis
	bibtex Thesis
	${latex} Thesis
	${latex} Thesis


clean:
	rubber --clean Thesis
	rm Thesis.tex
