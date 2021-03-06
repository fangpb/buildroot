######################################################################
#
# gdb
#
######################################################################
ifeq ($(BR2_TOOLCHAIN_SOURCE),y)
GDB_VERSION:=$(strip $(subst ",, $(BR2_GDB_VERSION)))
#"))
else
GDB_VERSION:=$(strip $(subst ",, $(BR2_EXT_GDB_VERSION)))
#"))
endif

ifeq ($(GDB_VERSION),snapshot)
# Be aware that this changes daily....
GDB_SITE:=ftp://sources.redhat.com/pub/gdb/snapshots/current
GDB_SOURCE:=gdb.tar.bz2
GDB_CAT:=$(BZCAT)
GDB_DIR:=$(TOOL_BUILD_DIR)/gdb-$(GDB_VERSION)
GDB_PATCH_DIR:=toolchain/gdb/$(GDB_VERSION)

else

ifeq ($(BR2_TOOLCHAIN_BUILDROOT),y)
GDB_SITE:=$(BR2_GNU_MIRROR)/gdb
else
GDB_SITE:=$(VENDOR_SITE)
endif

GDB_OFFICIAL_VERSION:=$(GDB_VERSION)$(VENDOR_SUFFIX)$(VENDOR_GDB_RELEASE)

GDB_SOURCE:=gdb-$(GDB_OFFICIAL_VERSION).tar.bz2
GDB_CAT:=$(BZCAT)

ifeq ($(BR2_TOOLCHAIN_BUILDROOT),y)
GDB_PATCH_DIR:=toolchain/gdb/$(GDB_OFFICIAL_VERSION)
else
GDB_PATCH_DIR:=$(VENDOR_PATCH_DIR)/gdb-$(GDB_OFFICIAL_VERSION)
endif

GDB_DIR:=$(TOOL_BUILD_DIR)/gdb-$(GDB_OFFICIAL_VERSION)

# NOTE: This option should not be used with gdb versions 6.4 and above.
ifeq ($(GDB_VERSION),6.2.1)
DISABLE_GDBMI:=--disable-gdbmi
endif

ifeq ($(GDB_VERSION),6.3)
DISABLE_GDBMI:=--disable-gdbmi
endif
endif

$(DL_DIR)/$(GDB_SOURCE):
	$(WGET) -P $(DL_DIR) $(GDB_SITE)/$(GDB_SOURCE)

gdb-unpacked: $(GDB_DIR)/.unpacked
$(GDB_DIR)/.unpacked: $(DL_DIR)/$(GDB_SOURCE)
	mkdir -p $(TOOL_BUILD_DIR)
	$(GDB_CAT) $(DL_DIR)/$(GDB_SOURCE) | tar -C $(TOOL_BUILD_DIR) $(TAR_OPTIONS) -
ifeq ($(GDB_VERSION),snapshot)
	GDB_REAL_DIR=$(shell \
		tar jtf $(DL_DIR)/$(GDB_SOURCE) | head -1 | cut -d"/" -f1)
	ln -sf $(TOOL_BUILD_DIR)/$(shell tar jtf $(DL_DIR)/$(GDB_SOURCE) | head -1 | cut -d"/" -f1) $(GDB_DIR)
endif
	toolchain/patch-kernel.sh $(GDB_DIR) $(GDB_PATCH_DIR) \*.patch
	$(SED) '/^ac_subdirs_all/s/ testsuite//g' \
		-e '/^subdirs/s/ testsuite//g' $(@D)/gdb/configure
	$(CONFIG_UPDATE) $(@D)
	$(CONFIG_UPDATE) $(@D)/readline/support
	touch $@

gdb-dirclean:
	rm -rf $(GDB_DIR)

######################################################################
#
# gdb target
#
######################################################################

GDB_TARGET_DIR:=$(BUILD_DIR)/gdb-$(GDB_VERSION)-target

GDB_TARGET_CONFIGURE_VARS:= \
	ac_cv_type_uintptr_t=yes \
	gt_cv_func_gettext_libintl=yes \
	ac_cv_func_dcgettext=yes \
	gdb_cv_func_sigsetjmp=yes \
	bash_cv_func_strcoll_broken=no \
	bash_cv_must_reinstall_sighandlers=no \
	bash_cv_func_sigsetjmp=present \
	bash_cv_have_mbstate_t=yes

$(GDB_TARGET_DIR)/.configured: THIS_SRCDIR = $(GDB_DIR)
$(GDB_TARGET_DIR)/.configured: $(GDB_DIR)/.unpacked
	mkdir -p $(GDB_TARGET_DIR)
	(cd $(GDB_TARGET_DIR); rm -rf config.cache; \
		gdb_cv_func_sigsetjmp=yes \
		$(AUTO_CONFIGURE_TARGET) \
		--prefix=/usr \
		$(DISABLE_NLS) \
		--without-uiout $(DISABLE_GDBMI) \
		--disable-tui --disable-gdbtk --without-x \
		--disable-sim --enable-gdbserver \
		--without-included-gettext \
		--disable-werror \
	)
ifeq ($(BR2_ENABLE_LOCALE),y)
	-$(SED) "s,^INTL *=.*,INTL = -lintl,g;" $(GDB_DIR)/gdb/Makefile
endif
	touch $@

$(GDB_TARGET_DIR)/gdb/gdb: $(GDB_TARGET_DIR)/.configured
	$(MAKE) -C $(GDB_TARGET_DIR)
	touch -c $@

$(TARGET_DIR)/usr/bin/gdb: $(GDB_TARGET_DIR)/gdb/gdb
	$(INSTALL) -D -m 0755 $(GDB_TARGET_DIR)/gdb/gdb $@
	$(STRIPCMD) $(STRIP_STRIP_ALL) $@

gdb_target: ncurses $(TARGET_DIR)/usr/bin/gdb

gdb_target-source: $(DL_DIR)/$(GDB_SOURCE)

gdb_target-clean:
	-$(MAKE) -C $(GDB_TARGET_DIR) clean
	rm -f $(TARGET_DIR)/usr/bin/gdb

gdb_target-dirclean:
	rm -rf $(GDB_TARGET_DIR)

######################################################################
#
# gdbserver
#
######################################################################

GDB_SERVER_DIR:=$(BUILD_DIR)/gdbserver-$(GDB_VERSION)

$(GDB_SERVER_DIR)/.configured: THIS_SRCDIR = $(GDB_DIR)/gdb/gdbserver
$(GDB_SERVER_DIR)/.configured: $(GDB_DIR)/.unpacked
	mkdir -p $(GDB_SERVER_DIR)
	(cd $(GDB_SERVER_DIR); rm -rf config.cache; \
		gdb_cv_func_sigsetjmp=yes \
		bash_cv_have_mbstate_t=yes \
		$(AUTO_CONFIGURE_TARGET) \
		--prefix=/usr \
		--exec-prefix=/usr \
		--bindir=/usr/bin \
		--sbindir=/usr/sbin \
		--libexecdir=/usr/lib \
		--sysconfdir=/etc \
		--datadir=/usr/share \
		--localstatedir=/var \
		--mandir=/usr/share/man \
		--infodir=/usr/share/info \
		--includedir=$(STAGING_DIR)/usr/include \
		$(DISABLE_NLS) \
		--without-uiout $(DISABLE_GDBMI) \
		--disable-tui --disable-gdbtk --without-x \
		--without-included-gettext \
	)
	touch $@

$(GDB_SERVER_DIR)/gdbserver: $(GDB_SERVER_DIR)/.configured
	$(MAKE) -C $(GDB_SERVER_DIR)

$(TARGET_DIR)/usr/bin/gdbserver: $(GDB_SERVER_DIR)/gdbserver
ifeq ($(BR2_CROSS_TOOLCHAIN_TARGET_UTILS),y)
	$(INSTALL) -d $(STAGING_DIR)/$(REAL_GNU_TARGET_NAME)/target_utils
	$(INSTALL) -D -m 0755 $(GDB_SERVER_DIR)/gdbserver \
		$(STAGING_DIR)/$(REAL_GNU_TARGET_NAME)/target_utils/gdbserver
endif
	$(INSTALL) -D -m 0755 $(GDB_SERVER_DIR)/gdbserver $@
	$(STRIPCMD) $(STRIP_STRIP_ALL) $@

gdbserver: $(TARGET_DIR)/usr/bin/gdbserver

gdbserver-clean:
	-$(MAKE) -C $(GDB_SERVER_DIR) clean
	rm -f $(TARGET_DIR)/usr/bin/gdbserver

gdbserver-dirclean:
	rm -rf $(GDB_SERVER_DIR)

######################################################################
#
# gdb on host
#
######################################################################

GDB_HOST_DIR:=$(TOOL_BUILD_DIR)/gdbhost-$(GDB_VERSION)

$(GDB_HOST_DIR)/.configured: $(GDB_DIR)/.unpacked
	mkdir -p $(GDB_HOST_DIR)
	(cd $(GDB_HOST_DIR); rm -rf config.cache; \
		gdb_cv_func_sigsetjmp=yes \
		bash_cv_have_mbstate_t=yes \
		$(GDB_DIR)/configure \
		--prefix=$(STAGING_DIR) \
		--build=$(GNU_HOST_NAME) \
		--host=$(GNU_HOST_NAME) \
		--target=$(REAL_GNU_TARGET_NAME) \
		$(DISABLE_NLS) \
		--without-uiout $(DISABLE_GDBMI) \
		--disable-tui --disable-gdbtk --without-x \
		--without-included-gettext \
		--enable-threads \
	)
	touch $@

$(GDB_HOST_DIR)/gdb/gdb: $(GDB_HOST_DIR)/.configured
	$(MAKE) -C $(GDB_HOST_DIR)
	strip $(GDB_HOST_DIR)/gdb/gdb

$(TARGET_CROSS)gdb: $(GDB_HOST_DIR)/gdb/gdb
	$(INSTALL) -D $(GDB_HOST_DIR)/gdb/gdb $(TARGET_CROSS)gdb
	ln -snf ../../bin/$(REAL_GNU_TARGET_NAME)-gdb \
		$(STAGING_DIR)/usr/$(REAL_GNU_TARGET_NAME)/bin/gdb
	ln -snf $(REAL_GNU_TARGET_NAME)-gdb \
		$(STAGING_DIR)/usr/bin/$(GNU_TARGET_NAME)-gdb

gdbhost: $(TARGET_CROSS)gdb

gdbhost-clean:
	-$(MAKE) -C $(GDB_HOST_DIR) clean
	rm -f $(TARGET_CROSS)gdb

gdbhost-dirclean:
	rm -rf $(GDB_HOST_DIR)

#############################################################
#
# Toplevel Makefile options
#
#############################################################
ifeq ($(BR2_PACKAGE_GDB),y)
TARGETS+=gdb_target
endif

ifeq ($(BR2_PACKAGE_GDB_SERVER),y)
TARGETS+=gdbserver
endif

ifeq ($(BR2_PACKAGE_GDB_HOST),y)
TARGETS+=gdbhost
endif
ifeq ($(findstring y,$(BR2_PACKAGE_GDB_SERVER)$(BR2_PACKAGE_GDB_HOST)),y)
HOST_SOURCE+=gdb-source
endif
