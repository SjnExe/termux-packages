TERMUX_PKG_HOMEPAGE=https://www.r-project.org/
TERMUX_PKG_DESCRIPTION="A free software environment for statistical computing and graphics"
TERMUX_PKG_LICENSE="GPL-2.0, GPL-3.0"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="4.6.2"
TERMUX_PKG_SRCURL=https://cloud.r-project.org/src/base/R-${TERMUX_PKG_VERSION%%.*}/R-${TERMUX_PKG_VERSION}.tar.gz
TERMUX_PKG_SHA256=c297040f6392b1dac6e5c0eb398422cfdaedf540ae2205edb9ad0d10cb10ee00
TERMUX_PKG_DEPENDS="bzip2, clang, flang, libandroid-complex-math, libcairo, libcurl, libiconv, libicu, libjpeg-turbo, liblzma, libopenblas, libpng, libtiff, make, pango, pcre2, readline, zlib"
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_EXCLUDED_ARCHES="arm, i686"
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
--without-x
--disable-java
--without-tcltk
--enable-R-shlib
--with-blas=-lopenblas
--with-lapack=-lopenblas
--with-cairo
--with-readline
--with-pcre2
--with-ICU
--with-internal-tzcode
ac_cv_have_decl_wctrans=yes
ac_cv_func_wctrans=yes
"

termux_step_pre_configure() {
	termux_setup_flang
	export F77="$FC"
	export FFLAGS="$FCFLAGS"
	export TZ=UTC
	LDFLAGS+=" -landroid-complex-math"
}

termux_step_post_configure() {
	sed -i 's|^SHLIB_LIBADD =.*|SHLIB_LIBADD = -lm|' etc/Makeconf
}
