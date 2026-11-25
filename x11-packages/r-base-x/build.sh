TERMUX_PKG_HOMEPAGE=https://www.r-project.org/
TERMUX_PKG_DESCRIPTION="A free software environment for statistical computing and graphics (with X11 and Tcl/Tk support)"
TERMUX_PKG_LICENSE="GPL-2.0, GPL-3.0"
TERMUX_PKG_MAINTAINER="@SjnExe"
TERMUX_PKG_VERSION="4.6.2"
TERMUX_PKG_SRCURL=https://cloud.r-project.org/src/base/R-${TERMUX_PKG_VERSION%%.*}/R-${TERMUX_PKG_VERSION}.tar.gz
TERMUX_PKG_SHA256=c297040f6392b1dac6e5c0eb398422cfdaedf540ae2205edb9ad0d10cb10ee00
TERMUX_PKG_DEPENDS="bzip2, clang, flang, libandroid-complex-math, libcairo, libcurl, libiconv, libicu, libjpeg-turbo, liblzma, libopenblas, libpng, libtiff, libx11, libxt, make, pango, pcre2, readline, tcl, tk, zlib"
TERMUX_PKG_CONFLICTS="r-base"
TERMUX_PKG_REPLACES="r-base"
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_HOSTBUILD=true
TERMUX_PKG_EXCLUDED_ARCHES="arm, i686"
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
--with-x
--disable-java
--with-tcltk
--with-tcl-config=$TERMUX_PREFIX/lib/tclConfig.sh
--with-tk-config=$TERMUX_PREFIX/lib/tkConfig.sh
--enable-R-shlib
--with-blas=-lopenblas
--with-lapack=-lopenblas
--with-cairo
--with-readline
--with-pcre2
--with-ICU
--with-internal-tzcode
R_SHELL=$TERMUX_PREFIX/bin/sh
ac_cv_have_decl_wctrans=yes
ac_cv_func_wctrans=yes
"

termux_step_post_get_source() {
	local ver_cli
	ver_cli=$(. "$TERMUX_SCRIPTDIR/packages/r-base/build.sh"; echo "$TERMUX_PKG_VERSION")
	if [ "$TERMUX_PKG_VERSION" != "$ver_cli" ]; then
		termux_error_exit "Version mismatch between r-base and r-base-x."
	fi
}

termux_step_host_build() {
	if [ "$TERMUX_ON_DEVICE_BUILD" = "true" ]; then
		return
	fi

	termux_download_ubuntu_packages \
		gfortran \
		gfortran-x86-64-linux-gnu \
		gfortran-15 \
		gfortran-15-x86-64-linux-gnu \
		libgfortran-15-dev \
		libgfortran5 \
		libbz2-dev \
		libbz2-1.0 \
		liblzma-dev \
		liblzma5 \
		libpcre2-dev \
		libpcre2-8-0 \
		libpcre2-16-0 \
		libpcre2-32-0 \
		libpcre2-posix3

	local HOSTBUILD_ROOTFS="$TERMUX_PKG_HOSTBUILD_DIR/ubuntu_packages"
	find "$HOSTBUILD_ROOTFS" -type f -name '*.pc' -print0 | \
		xargs -0 -n 1 sed -i -e "s|/usr|$HOSTBUILD_ROOTFS/usr|g"
	find "$HOSTBUILD_ROOTFS" -xtype l | while read -r l; do
		local target
		target="$(readlink "$l")"
		if [[ "$target" == /* ]]; then
			ln -snfv "${HOSTBUILD_ROOTFS}${target}" "$l"
		fi
	done

	mkdir -p "$TERMUX_PKG_HOSTBUILD_DIR/wrapper-bin"
	cat <<- EOF > "$TERMUX_PKG_HOSTBUILD_DIR/wrapper-bin/gfortran"
		#!/bin/bash
		exec "$HOSTBUILD_ROOTFS/usr/bin/x86_64-linux-gnu-gfortran-15" \
			-B"$HOSTBUILD_ROOTFS/usr/libexec/gcc/x86_64-linux-gnu/15" \
			-L"$HOSTBUILD_ROOTFS/usr/lib/gcc/x86_64-linux-gnu/15" \
			-L"$HOSTBUILD_ROOTFS/usr/lib/x86_64-linux-gnu" \
			"\$@"
	EOF
	chmod +x "$TERMUX_PKG_HOSTBUILD_DIR/wrapper-bin/gfortran"

	(
		patch -d "$TERMUX_PKG_SRCDIR" -p1 -N < "$TERMUX_PKG_BUILDER_DIR/0002-android-timezone.patch"
		grep -rl '@WHICH@' "$TERMUX_PKG_SRCDIR/src/library/" | xargs -r sed -i 's|@WHICH@|which|g'
		export PATH="$TERMUX_PKG_HOSTBUILD_DIR/wrapper-bin:$HOSTBUILD_ROOTFS/usr/bin:$PATH"
		export CPPFLAGS="-I$HOSTBUILD_ROOTFS/usr/include -I$HOSTBUILD_ROOTFS/usr/include/x86_64-linux-gnu"
		export LDFLAGS="-L$HOSTBUILD_ROOTFS/usr/lib/x86_64-linux-gnu -Wl,-rpath,$HOSTBUILD_ROOTFS/usr/lib/x86_64-linux-gnu"
		export LD_LIBRARY_PATH="$HOSTBUILD_ROOTFS/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
		export FFLAGS="-O2 -fno-tree-vectorize"
		export FLIBS="-L$HOSTBUILD_ROOTFS/usr/lib/gcc/x86_64-linux-gnu/15 -L$HOSTBUILD_ROOTFS/usr/lib/x86_64-linux-gnu -lgfortran -lm -lmvec"
		export ac_cv_fc_libs="$FLIBS"
		export ac_cv_f77_libs="$FLIBS"
		export TZ=UTC

		"$TERMUX_PKG_SRCDIR/configure" \
			--without-x \
			--disable-java \
			--without-tcltk \
			--without-ICU \
			--without-readline \
			--without-cairo
		make -j "$TERMUX_PKG_MAKE_PROCESSES"
		patch -d "$TERMUX_PKG_SRCDIR" -p1 -R < "$TERMUX_PKG_BUILDER_DIR/0002-android-timezone.patch"
	)
}

termux_step_pre_configure() {
	termux_setup_flang
	export F77="$FC"
	export FFLAGS="$FCFLAGS"
	export TZ=UTC

	sed -i "s|\"/bin/sh\"|\"$TERMUX_PREFIX/bin/sh\"|g" "$TERMUX_PKG_SRCDIR/src/unix/sys-unix.c"

	if [ "$TERMUX_ON_DEVICE_BUILD" = "false" ]; then
		local flang_toolchain_dir
		flang_toolchain_dir="$(dirname "$(dirname "$(command -v flang-new)")")"
		local flang_libs_dir="$flang_toolchain_dir/sysroot/usr/lib/$TERMUX_HOST_PLATFORM"
		mkdir -p "$TERMUX_PKG_TMPDIR/_deps"
		ln -sf "$flang_libs_dir/libflang_rt.runtime.a" "$TERMUX_PKG_TMPDIR/_deps/"
		export ac_cv_f77_libs="-L$TERMUX_PKG_TMPDIR/_deps -l:libflang_rt.runtime.a"
		export ac_cv_fc_libs="-L$TERMUX_PKG_TMPDIR/_deps -l:libflang_rt.runtime.a"
		export r_cv_func_calloc_works=yes
		export r_cv_func_isfinite_works=yes
		export r_cv_func_log1p_works=yes
		export r_cv_working_ftell=yes
		export r_cv_header_zlib_h=yes
		export r_cv_have_bzlib=yes
		export r_cv_have_lzma=yes
		export r_cv_have_pcre2utf=yes
		export r_cv_size_max=yes
		export r_cv_iconv_latin1=yes
		export r_cv_iconv_cp1252=yes
		export r_cv_putenv_unset=no
		export r_cv_putenv_unset2=no
		export r_cv_func_sigaction_works=yes
		export r_cv_icu=yes
		export r_cv_have_curl728=yes
		export r_cv_have_curl_https=yes
		export r_cv_func_ctanh_works=yes
		export r_cv_zdotu_is_usable=yes
		# Prevent configure from exporting target LD_LIBRARY_PATH (/data/data/.../lib) into host x86_64 bash
		sed -i -e 's/eval "\${Rshlibpath_var}=.*/:/g' -e 's/eval "export \${Rshlibpath_var}"/:/g' "$TERMUX_PKG_SRCDIR/configure"
	fi

	LDFLAGS+=" -landroid-complex-math"
}

termux_step_post_configure() {
	sed -i 's|^SHLIB_LIBADD =.*|SHLIB_LIBADD = -lm|' etc/Makeconf
}

termux_step_make() {
	if [ "$TERMUX_ON_DEVICE_BUILD" = "true" ]; then
		make -j "$TERMUX_PKG_MAKE_PROCESSES"
		make -j "$TERMUX_PKG_MAKE_PROCESSES" docs
		return
	fi

	local HOSTBUILD_ROOTFS="$TERMUX_PKG_HOSTBUILD_DIR/ubuntu_packages"
	export LD_LIBRARY_PATH="$HOSTBUILD_ROOTFS/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
	local host_r="$TERMUX_PKG_HOSTBUILD_DIR/bin/R"

	# Build core R scripts, binaries, libR.so, modules, and base/library C/Fortran .so files
	for sub in scripts include extra appl nmath unix main modules; do
		make -j "$TERMUX_PKG_MAKE_PROCESSES" -C "src/$sub"
	done
	for d in src/library/*/src; do
		if [ -f "$d/Makefile" ]; then
			make -j "$TERMUX_PKG_MAKE_PROCESSES" -C "$d"
		fi
	done

	# Copy platform-independent lazy-load DBs/help/Meta from hostbuild (never host .so files)
	mkdir -p library
	for pkg_dir in "$TERMUX_PKG_HOSTBUILD_DIR"/library/*; do
		local pkg
		pkg="$(basename "$pkg_dir")"
		mkdir -p "library/$pkg"
		for item in "$pkg_dir"/*; do
			[ "$(basename "$item")" = "libs" ] && continue
			cp -r "$item" "library/$pkg/"
		done
	done

	# Build Recommended packages using host R with target Makeconf, libR.so, and --no-test-load
	cp -f "$TERMUX_PKG_HOSTBUILD_DIR/etc/Makeconf" "$TERMUX_PKG_HOSTBUILD_DIR/etc/Makeconf.host"
	cp -f etc/Makeconf "$TERMUX_PKG_HOSTBUILD_DIR/etc/Makeconf"
	cp -f lib/libR.so "$TERMUX_PKG_HOSTBUILD_DIR/lib/libR.so"
	local pkg tgz
	for pkg in lattice nlme Matrix boot class cluster codetools foreign KernSmooth MASS mgcv nnet rpart spatial survival; do
		for tgz in src/library/Recommended/"${pkg}".tgz src/library/Recommended/"${pkg}"_*.tgz; do
			if [ -f "$tgz" ]; then
				R_LIBS="$TERMUX_PKG_HOSTBUILD_DIR/library" "$host_r" CMD INSTALL --no-test-load -l library "$tgz"
				break
			fi
		done
	done
	rm -f "$TERMUX_PKG_HOSTBUILD_DIR/lib/libR.so"
	mv -f "$TERMUX_PKG_HOSTBUILD_DIR/etc/Makeconf.host" "$TERMUX_PKG_HOSTBUILD_DIR/etc/Makeconf"

	sed -i -e "s|\$(top_builddir)/bin/Rscript|$TERMUX_PKG_HOSTBUILD_DIR/bin/Rscript|g" \
		-e "s|\$(top_builddir)/bin/R|$host_r|g" doc/Makefile
	mkdir -p share/bibliographies share/dictionaries
	cp -f "$TERMUX_PKG_HOSTBUILD_DIR"/share/bibliographies/*.rds share/bibliographies/
	cp -f "$TERMUX_PKG_HOSTBUILD_DIR"/share/dictionaries/*.rds share/dictionaries/
	for sub in etc share po doc; do
		make -j "$TERMUX_PKG_MAKE_PROCESSES" -C "$sub" R_EXE="$host_r --vanilla --no-echo"
	done
}

termux_step_make_install() {
	if [ "$TERMUX_ON_DEVICE_BUILD" = "true" ]; then
		make install
		return
	fi

	local HOSTBUILD_ROOTFS="$TERMUX_PKG_HOSTBUILD_DIR/ubuntu_packages"
	export LD_LIBRARY_PATH="$HOSTBUILD_ROOTFS/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
	rm -rf "$TERMUX_PREFIX/lib/R"
	make install R_EXE="$TERMUX_PKG_HOSTBUILD_DIR/bin/R --vanilla --no-echo"
	sed -i "s|/usr/bin/|$TERMUX_PREFIX/bin/|g" "$TERMUX_PREFIX/lib/R/etc/Renviron"
	local pkg
	for pkg in lattice nlme Matrix boot class cluster codetools foreign KernSmooth MASS mgcv nnet rpart spatial survival; do
		if [ -d "library/$pkg" ]; then
			rm -rf "$TERMUX_PREFIX/lib/R/library/$pkg"
			cp -r "library/$pkg" "$TERMUX_PREFIX/lib/R/library/"
		fi
	done
}
