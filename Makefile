all: Thesis.md Thesis.template
	pandoc -t latex Thesis.md -o Thesis.tex \
		--standalone \
		--chapter \
		--toc \
		--smart \
		--listings \
		--bibliography=Thesis.bib \
		--biblatex

	rubber -d Thesis 
	rubber --clean Thesis

clean:
	rubber --clean Thesis
