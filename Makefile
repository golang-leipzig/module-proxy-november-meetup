slides: slides.html

slides.html: slides.md
	@pandoc $< --output $@ --to revealjs --standalone\
		--variable revealjs-url=https://revealjs.com\
		--variable theme:white\
		--variable transition:none

open: slides.html
	xdg-open $<
