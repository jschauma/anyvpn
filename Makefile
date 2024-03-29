NAME= anyvpn

PREFIX?=/usr/local

help:
	@echo "The following targets are available:"
	@echo "install  install ${NAME} under ${PREFIX}"
	@echo "readme   generate the README after a manual page update"

install:
	mkdir -p ${PREFIX}/bin ${PREFIX}/share/man/man1
	install -c -m 555 src/${NAME}.sh ${PREFIX}/bin/${NAME}
	install -c -m 444 doc/${NAME}.1 ${PREFIX}/share/man/man1/${NAME}.1

man: doc/${NAME}.1.txt

doc/${NAME}.1.txt: doc/${NAME}.1
	mandoc -c -O width=80 $? | col -b >$@

readme: man
	sed -n -e '/^NAME/!p;//q' README.md >.readme
	sed -n -e '/^NAME/,$$p' -e '/emailing/q' doc/${NAME}.1.txt >>.readme
	echo '```' >>.readme
	mv .readme README.md
