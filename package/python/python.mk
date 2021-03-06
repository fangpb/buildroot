#############################################################
#
# python
#
#############################################################
PYTHON_VERSION=2.4.2
PYTHON_SOURCE:=Python-$(PYTHON_VERSION).tar.bz2
PYTHON_SITE:=http://python.org/ftp/python/$(PYTHON_VERSION)
PYTHON_DIR:=$(BUILD_DIR)/Python-$(PYTHON_VERSION)
PYTHON_CAT:=$(BZCAT)
PYTHON_BINARY:=python
PYTHON_TARGET_BINARY:=usr/bin/python

# these could use checks for some BR2_PACKAGE_foo,y
BR2_PYTHON_DISABLED_MODULES=readline pyexpat dbm gdbm bsddb \
	_curses _curses_panel _tkinter nis zipfile

$(DL_DIR)/$(PYTHON_SOURCE):
	 $(WGET) -P $(DL_DIR) $(PYTHON_SITE)/$(PYTHON_SOURCE)

python-source: $(DL_DIR)/$(PYTHON_SOURCE)

$(PYTHON_DIR)/.unpacked: $(DL_DIR)/$(PYTHON_SOURCE)
	$(PYTHON_CAT) $(DL_DIR)/$(PYTHON_SOURCE) | tar -C $(BUILD_DIR) $(TAR_OPTIONS) -
	touch $@

$(PYTHON_DIR)/.patched: $(PYTHON_DIR)/.unpacked
	toolchain/patch-kernel.sh $(PYTHON_DIR) package/python/ python\*.patch
	touch $@

$(PYTHON_DIR)/.hostpython: $(PYTHON_DIR)/.patched
	(cd $(PYTHON_DIR); rm -rf config.cache; \
		CC="$(HOSTCC)" OPT="-O2" \
		./configure \
		--with-cxx=no \
		$(DISABLE_NLS) && \
		$(MAKE) python Parser/pgen && \
		mv python hostpython && \
		mv Parser/pgen Parser/hostpgen && \
		-$(MAKE) distclean \
	) && \
	touch $@

$(PYTHON_DIR)/.configured: $(PYTHON_DIR)/.hostpython
	(cd $(PYTHON_DIR); rm -rf config.cache; \
		$(TARGET_CONFIGURE_OPTS) \
		$(TARGET_CONFIGURE_ARGS) \
		OPT="$(TARGET_CFLAGS)" \
		./configure \
		--target=$(GNU_TARGET_NAME) \
		--host=$(GNU_TARGET_NAME) \
		--build=$(GNU_HOST_NAME) \
		--prefix=/usr \
		--sysconfdir=/etc \
		--with-cxx=no \
		$(DISABLE_IPV6) \
		$(DISABLE_NLS) \
	)
	touch $@

$(PYTHON_DIR)/$(PYTHON_BINARY): $(PYTHON_DIR)/.configured
	export PYTHON_DISABLE_SSL=1
	$(MAKE) CC=$(TARGET_CC) -C $(PYTHON_DIR) DESTDIR=$(TARGET_DIR) \
		PYTHON_MODULES_INCLUDE=$(STAGING_DIR)/usr/include \
		PYTHON_MODULES_LIB=$(STAGING_DIR)/lib \
		PYTHON_DISABLE_MODULES="$(BR2_PYTHON_DISABLED_MODULES)" \
		HOSTPYTHON=./hostpython HOSTPGEN=./Parser/hostpgen

$(TARGET_DIR)/$(PYTHON_TARGET_BINARY): $(PYTHON_DIR)/$(PYTHON_BINARY)
	export PYTHON_DISABLE_SSL=1
	LD_LIBRARY_PATH=$(STAGING_DIR)/lib
	$(MAKE) CC=$(TARGET_CC) -C $(PYTHON_DIR) install \
		DESTDIR=$(TARGET_DIR) CROSS_COMPILE=yes \
		PYTHON_MODULES_INCLUDE=$(STAGING_DIR)/usr/include \
		PYTHON_MODULES_LIB=$(STAGING_DIR)/lib \
		PYTHON_DISABLE_MODULES="$(BR2_PYTHON_DISABLED_MODULES)" \
		HOSTPYTHON=./hostpython HOSTPGEN=./Parser/hostpgen && \
	rm $(TARGET_DIR)/usr/bin/python?.? && \
	rm $(TARGET_DIR)/usr/bin/idle && \
	rm $(TARGET_DIR)/usr/bin/pydoc && \
	find $(TARGET_DIR)/usr/lib/ -name '*.pyc' -exec rm {} \; && \
	find $(TARGET_DIR)/usr/lib/ -name '*.pyo' -exec rm {} \; && \
	rm -rf $(TARGET_DIR)/share/locale $(TARGET_DIR)/usr/info \
		$(TARGET_DIR)/usr/man $(TARGET_DIR)/usr/share/doc \
		$(TARGET_DIR)/usr/lib/python*/test

python: uclibc $(TARGET_DIR)/$(PYTHON_TARGET_BINARY)

python-clean:
	-$(MAKE) -C $(PYTHON_DIR) distclean
	rm $(PYTHON_DIR)/.configured $(TARGET_DIR)/$(PYTHON_TARGET_BINARY)

python-dirclean:
	rm -rf $(PYTHON_DIR)
#############################################################
#
# Toplevel Makefile options
#
#############################################################
ifeq ($(BR2_PACKAGE_PYTHON),y)
TARGETS+=python
endif
