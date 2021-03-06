################################################################################
#
# xlib_libXprintUtil -- X.Org XprintUtil library
#
################################################################################

XLIB_LIBXPRINTUTIL_VERSION = 1.0.1
XLIB_LIBXPRINTUTIL_SOURCE = libXprintUtil-$(XLIB_LIBXPRINTUTIL_VERSION).tar.bz2
XLIB_LIBXPRINTUTIL_SITE = http://xorg.freedesktop.org/releases/individual/lib
XLIB_LIBXPRINTUTIL_AUTORECONF = YES
XLIB_LIBXPRINTUTIL_INSTALL_STAGING = YES
XLIB_LIBXPRINTUTIL_DEPENDENCIES = xlib_libX11 xlib_libXp xlib_libXt xproto_printproto
XLIB_LIBXPRINTUTIL_CONF_OPT = --enable-shared --disable-static

$(eval $(call AUTOTARGETS,package/x11r7,xlib_libXprintUtil))
