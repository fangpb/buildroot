#############################################################
#
# at
#
#############################################################
AT_VERSION:=3.1.10
AT_SOURCE:=at_$(AT_VERSION).tar.gz
AT_SITE:=$(BR2_DEBIAN_MIRROR)/debian/pool/main/a/at
AT_DIR:=$(BUILD_DIR)/at-$(AT_VERSION)
AT_CAT:=$(ZCAT)
AT_TARGET_SCRIPT:=etc/init.d/S99at
AT_BINARY:=at

$(DL_DIR)/$(AT_SOURCE):
	 $(WGET) -P $(DL_DIR) $(AT_SITE)/$(AT_SOURCE)

$(AT_DIR)/.unpacked: $(DL_DIR)/$(AT_SOURCE)
	$(AT_CAT) $(DL_DIR)/$(AT_SOURCE) | tar -C $(BUILD_DIR) $(TAR_OPTIONS) -
	toolchain/patch-kernel.sh $(AT_DIR) package/at/ at\*.patch
	$(CONFIG_UPDATE) $(@D)
	touch $@

$(AT_DIR)/.configured: $(AT_DIR)/.unpacked
	(cd $(AT_DIR); rm -rf config.cache; \
		$(AUTO_CONFIGURE_TARGET) \
		--prefix=/usr \
		--libdir=/lib \
		--libexecdir=/usr/lib \
		--sysconfdir=/etc \
		--localstatedir=/var \
		--mandir=/usr/share/man \
		--with-jobdir=/var/lib/atjobs \
		--with-atspool=/var/lib/atspool \
		--with-daemon_username=at \
		--with-daemon_groupname=at \
	)
	touch $@

$(AT_DIR)/$(AT_BINARY): $(AT_DIR)/.configured
	$(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(AT_DIR)
	touch $@

$(TARGET_DIR)/$(AT_TARGET_SCRIPT): $(AT_DIR)/$(AT_BINARY)
	# Use fakeroot to pretend to do 'make install' as root
	echo '$(MAKE) DAEMON_USERNAME=root DAEMON_GROUPNAME=root ' \
	 '$(TARGET_CONFIGURE_OPTS) DESTDIR=$(TARGET_DIR) -C $(AT_DIR) install' \
		> $(PROJECT_BUILD_DIR)/.fakeroot.at
ifneq ($(BR2_HAVE_MANPAGES),y)
	echo 'rm -rf $(TARGET_DIR)/usr/share/man' >> $(PROJECT_BUILD_DIR)/.fakeroot.at
endif
	echo 'rm -rf $(TARGET_DIR)/usr/doc/at' >> $(PROJECT_BUILD_DIR)/.fakeroot.at
	echo 'rm -rf $(TARGET_DIR)/usr/share/doc/at' >> $(PROJECT_BUILD_DIR)/.fakeroot.at
	$(INSTALL) -m 0755 -D $(AT_DIR)/debian/rc $(TARGET_DIR)/$(AT_TARGET_SCRIPT)

at: uclibc host-fakeroot $(TARGET_DIR)/$(AT_TARGET_SCRIPT)

at-source: $(DL_DIR)/$(AT_SOURCE)

at-clean:
	-$(MAKE) DESTDIR=$(TARGET_DIR) CC=$(TARGET_CC) -C $(AT_DIR) uninstall
	-$(MAKE) -C $(AT_DIR) clean
	rm -f $(TARGET_DIR)/$(AT_TARGET_SCRIPT) $(TARGET_DIR)/etc/init.d/S99at

at-dirclean:
	rm -rf $(AT_DIR)

#############################################################
#
# Toplevel Makefile options
#
#############################################################
ifeq ($(BR2_PACKAGE_AT),y)
TARGETS+=at
endif
