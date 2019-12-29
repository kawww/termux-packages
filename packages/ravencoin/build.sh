TERMUX_PKG_HOMEPAGE=https://ravencoin.org/
TERMUX_PKG_DESCRIPTION="Ravencoin Core"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_VERSION=2.5.1
TERMUX_PKG_SRCURL=https://github.com/RavenProject/Ravencoin/archive/v$TERMUX_PKG_VERSION.tar.gz
TERMUX_PKG_SHA256=b2fb077317640ead86848ef6198d70a97fad014110853e29bbe5ae1a16594a54
TERMUX_PKG_DEPENDS="boost, libevent, libzmq, miniupnpc"
TERMUX_PKG_CONFFILES="var/service/ravend/run var/service/ravend/log/run"
TERMUX_PKG_BUILD_IN_SRC=true

TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
--disable-tests
--with-daemon
--with-boost-chrono=boost_chrono
--with-boost-filesystem=boost_filesystem
--with-boost-system=boost_system
--with-boost-thread=boost_thread
--with-gui=no
--with-miniupnpc
--without-libs
"

termux_step_pre_configure() {
	local db_version=4.8.30
	local db_install_dir=$TERMUX_PKG_BUILDDIR/db-install
	local db_build_dir=$TERMUX_PKG_BUILDDIR/db-build

	termux_download https://download.oracle.com/berkeley-db/db-${db_version}.tar.gz \
		$TERMUX_PKG_CACHEDIR/db-${db_version}.tar.gz \
		e0491a07cdb21fb9aa82773bbbedaeb7639cbd0e7f96147ab46141e0045db72a

	tar xf $TERMUX_PKG_CACHEDIR/db-${db_version}.tar.gz

	cd $TERMUX_PKG_BUILDDIR/db-${db_version}
	sed -i.old 's/__atomic_compare_exchange/__atomic_compare_exchange_db/' \
		dbinc/atomic.h
	sed -i.old 's/atomic_init/atomic_init_db/' dbinc/atomic.h mp/mp_region.c \
		mp/mp_mvcc.c mp/mp_fget.c mutex/mut_method.c mutex/mut_tas.c
	termux_step_replace_guess_scripts

	mkdir -p ${db_build_dir}
	cd ${db_build_dir}
	../db-${db_version}/dist/configure \
		--host=$TERMUX_HOST_PLATFORM --prefix=${db_install_dir} \
		--disable-shared --enable-static --enable-hash --enable-smallbuild \
		--enable-compat185 --enable-cxx db_cv_atomic=gcc-builtin
	make -j $TERMUX_MAKE_PROCESSES
	make install_lib install_include
	cd $TERMUX_PKG_BUILDDIR

	export BDB_CFLAGS="-I${db_install_dir}/include -DHAVE_CXX_STDHEADERS=1"
	export BDB_LIBS="-L${db_install_dir}/lib -ldb_cxx"

    ./autogen.sh
}

termux_step_post_make_install() {
    mkdir -p $TERMUX_PREFIX/var/service
    cd $TERMUX_PREFIX/var/service
    mkdir -p ravend/log
    echo "#!$TERMUX_PREFIX/bin/sh" > ravend/run
    echo 'exec ravend 2>&1' >> ravend/run
    chmod +x ravend/run
    touch ravend/down

    ln -sf $TERMUX_PREFIX/share/termux-services/svlogger ravend/log/run
}
