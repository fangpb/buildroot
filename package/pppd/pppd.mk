#############################################################
#
# pppd
#
#############################################################
PPPD_VERSION:=2.4.4
PPPD_SOURCE:=ppp-$(PPPD_VERSION).tar.gz
PPPD_SITE:=ftp://ftp.samba.org/pub/ppp
PPPD_DIR:=$(BUILD_DIR)/ppp-$(PPPD_VERSION)
PPPD_CAT:=$(ZCAT)
PPPD_BINARY:=pppd/pppd
PPPD_TARGET_BINARY:=usr/sbin/pppd


$(DL_DIR)/$(PPPD_SOURCE):
	 $(WGET) -P $(DL_DIR) $(PPPD_SITE)/$(PPPD_SOURCE)

pppd-source: $(DL_DIR)/$(PPPD_SOURCE)

$(PPPD_DIR)/.unpacked: $(DL_DIR)/$(PPPD_SOURCE)
	$(PPPD_CAT) $(DL_DIR)/$(PPPD_SOURCE) | tar -C $(BUILD_DIR) $(TAR_OPTIONS) -
	$(SED) 's/ -DIPX_CHANGE -DHAVE_MMAP//' $(PPPD_DIR)/pppd/Makefile.linux
	$(SED) 's/HAVE_MULTILINK=y/#HAVE_MULTILINK=y/' $(PPPD_DIR)/pppd/Makefile.linux
	$(SED) 's/FILTER=y/#FILTER=y/' $(PPPD_DIR)/pppd/Makefile.linux
	$(SED) 's,(INSTALL) -s,(INSTALL),' $(PPPD_DIR)/*/Makefile.linux
	$(SED) 's,(INSTALL) -s,(INSTALL),' $(PPPD_DIR)/pppd/plugins/*/Makefile.linux
	$(SED) 's/ -o root//' $(PPPD_DIR)/*/Makefile.linux
	$(SED) 's/ -g daemon//' $(PPPD_DIR)/*/Makefile.linux
	$(CONFIG_UPDATE) $(@D)
	touch $@

$(PPPD_DIR)/.configured: $(PPPD_DIR)/.unpacked
	(cd $(PPPD_DIR); rm -rf config.cache; \
		$(AUTO_CONFIGURE_TARGET) \
		--prefix=/usr \
		--exec-prefix=/usr \
		--bindir=/usr/bin \
		--sbindir=/usr/sbin \
		--libdir=/lib \
		--libexecdir=/usr/lib \
		--sysconfdir=/etc \
		--datadir=/usr/share \
		--localstatedir=/var \
		--mandir=/usr/share/man \
		--infodir=/usr/share/info \
		$(DISABLE_NLS) \
	)
	touch $@

$(PPPD_DIR)/$(PPPD_BINARY): $(PPPD_DIR)/.configured
	$(MAKE) CC=$(TARGET_CC) COPTS="$(TARGET_CFLAGS)" -C $(PPPD_DIR)

$(TARGET_DIR)/$(PPPD_TARGET_BINARY): $(PPPD_DIR)/$(PPPD_BINARY)
	$(MAKE1) DESTDIR=$(TARGET_DIR)/usr CC=$(TARGET_CC) -C $(PPPD_DIR) install
ifneq ($(BR2_ENABLE_LOCALE),y)
	rm -rf $(TARGET_DIR)/usr/share/locale
endif
ifneq ($(BR2_HAVE_MANPAGES),y)
	rm -rf $(TARGET_DIR)/usr/share/man
endif
ifneq ($(BR2_HAVE_INFOPAGES),y)
	rm -rf $(TARGET_DIR)/usr/info
endif
	rm -rf $(TARGET_DIR)/usr/share/doc
	rm -rf $(TARGET_DIR)/usr/include/pppd

pppd: uclibc $(TARGET_DIR)/$(PPPD_TARGET_BINARY)

pppd-clean:
	rm -f $(TARGET_DIR)/usr/sbin/pppd
	rm -f $(TARGET_DIR)/usr/sbin/chat
	rm -f $(TARGET_DIR)/usr/sbin/pppstatus
	rm -f $(TARGET_DIR)/usr/sbin/pppdump
	rm -rf $(TARGET_DIR)/etc/ppp
	rm -rf $(TARGET_DIR)/usr/include/pppd
	-$(MAKE) -C $(PPPD_DIR) clean

pppd-dirclean:
	rm -rf $(PPPD_DIR)


#############################################################
#
# Toplevel Makefile options
#
#############################################################
ifeq ($(BR2_PACKAGE_PPPD),y)
TARGETS+=pppd
endif
