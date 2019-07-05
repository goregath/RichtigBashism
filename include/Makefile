## Makefile to install libs
##
## @file
## @author              Oliver Zimmer <Oliver.Zimmer@e3dc.com>
## @date                2019-05-22 10:36:37
##
## Last Modified time:  2019-07-05 12:34:24
## Last Modified by:    GoreGath

ifndef DEST_DIR
DEST_DIR=/usr/local
endif

.PHONY: install install-execution install-logger install-web

install: install-execution install-logger install-web

${DEST_DIR}/bin:
	mkdir -p ${DEST_DIR}/bin

install-execution: ${DEST_DIR}/bin execution.sh
	cp -v execution.sh --target ${DEST_DIR}/bin
	chmod +x ${DEST_DIR}/bin/execution.sh

install-logger: ${DEST_DIR}/bin logger.sh
	cp -v logger.sh --target ${DEST_DIR}/bin
	chmod +x ${DEST_DIR}/bin/logger.sh

install-web: ${DEST_DIR}/bin web.sh
	cp -v web.sh --target ${DEST_DIR}/bin
	chmod +x ${DEST_DIR}/bin/web.sh