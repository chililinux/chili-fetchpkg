#!/bin/sh

BINDIR=/usr/bin
CONFDIR=/etc
CACHE_DIR=/var/cache/scratchpkg
PORT_DIR=/usr/ports
REVDEPD=/etc/revdep.d
REVDEPCONF=/etc/revdep.conf

install -dv ${DESTDIR}${BINDIR}
install -dv ${DESTDIR}${CONFDIR}
install -dv ${DESTDIR}${PORT_DIR}
install -dv ${DESTDIR}${REVDEPD}
install -dv "/var/lib/scratchpkg/db"

install -vdm777 ${DESTDIR}${CACHE_DIR}/packages
install -vdm777 ${DESTDIR}${CACHE_DIR}/sources
install -vdm777 ${DESTDIR}${CACHE_DIR}/work

install -m644 fetchpkg.conf fetchpkg.repo fetchpkg.alias fetchpkg.mask ${DESTDIR}${CONFDIR}

#install -m755 xchroot revdep pkgadd pkgdel pkgbuild scratch updateconf portsync pkgbase pkgdepends pkgrebuild portcreate ${DESTDIR}${BINDIR}
#install -m644 scratchpkg.conf scratchpkg.repo scratchpkg.alias scratchpkg.mask ${DESTDIR}${CONFDIR}
#install -m644 revdep.conf ${DESTDIR}${REVDEPCONF}
