BUILD_VERSION?="$(shell git for-each-ref --sort=-v:refname --count=1 --format '%(refname)'  | cut -d '/' -f3)"
OUTDIR="crowdsec-haproxy-bouncer-${BUILD_VERSION}/"
LUA_MOD_DIR="${OUTDIR}lua-mod"
CONFIG_DIR="${OUTDIR}config"
OUT_ARCHIVE="crowdsec-haproxy-bouncer.tgz"
LUA_BOUNCER_BRANCH?=main
default: release
release: 
	mkdir -p ${LUA_MOD_DIR}/lib
	cp -r lib/* "${LUA_MOD_DIR}"/lib
	mkdir -p ${LUA_MOD_DIR}/templates
	cp -r templates/* "${LUA_MOD_DIR}"/templates
	
	cp community_blocklist.map ${LUA_MOD_DIR}

	cp install.sh ${OUTDIR}
	chmod +x ${OUTDIR}install.sh

	cp uninstall.sh ${OUTDIR}
	chmod +x ${OUTDIR}uninstall.sh

	cp upgrade.sh ${OUTDIR}
	chmod +x ${OUTDIR}upgrade.sh

	tar cvzf ${OUT_ARCHIVE} ${OUTDIR}
	rm -rf ${OUTDIR}

clean:
	rm -rf "${OUTDIR}"
	rm -rf "${OUT_ARCHIVE}"
