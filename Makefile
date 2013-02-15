###################################################
# Variables that may change

# Arches to build
ARCHES = i386 amd64

# Ubuntu codename data
UBUNTU_CODENAMES = precise lucid
UBUNTU_MIRROR = http://archive.ubuntu.com/ubuntu

# Debian codename data
DEBIAN_CODENAMES = squeeze
DEBIAN_MIRROR = http://ftp.at.debian.org/debian/

# Ubuntu keys
UBUNTU_KEYID = 40976EAF437D05B5
UBUNTU_KEYRING = $(TOPDIR)/admin/ubuntu-keyring.gpg
KEYSERVER = hkp://keys.gnupg.net

# Xenomai package
PACKAGES += xenomai
GITURL_XENOMAI = git@github.com:zultron/xenomai-src.git
GITBRANCH_XENOMAI = v2.6.2.1-deb

###################################################
# Variables that should not change much
# (or auto-generated)

# Other variables
TOPDIR = $(shell pwd)
SUDO = sudo
DIRS = admin tmp src git
ALLDIRS = $(patsubst %,%/.dir-exists,$(DIRS) $(CODENAMES))
CODENAMES = $(UBUNTU_CODENAMES) $(DEBIAN_CODENAMES)
BASE_CHROOT_TARBALLS = $(foreach C,$(CODENAMES),$(foreach A,$(ARCHES),\
  $(C)/base-$(A).tgz))


###################################################
# Functions

# Given codename, return mirror
MIRROR = $(if $(findstring $(1),$(UBUNTU_CODENAMES)),$(UBUNTU_MIRROR),\
	$(if $(findstring $(1),$(DEBIAN_CODENAMES)),$(DEBIAN_MIRROR)))

# Given codename, return --keyring arg
KEYRING_OPT = $(if $(findstring $(1),$(UBUNTU_CODENAMES)),\
	--keyring $(TOPDIR)/admin/ubuntu-keyring.gpg)

# Given codename, return --debootstrapopts --keyring= args to pbuilder
DEBOOTSTRAPOPTS = $(if $(findstring $(1),$(UBUNTU_CODENAMES)),\
	--debootstrapopts --keyring=$(TOPDIR)/admin/ubuntu-keyring.gpg)


###################################################
# out-of-band checks

# check that pbuilder exists
ifeq ($(shell /bin/ls /usr/sbin/pbuilder 2>/dev/null),)
  $(error /usr/sbin/pbuilder does not exist)
endif


###################################################
# Misc rules

.PHONY:  all
all:  $(BASE_CHROOT_TARBALLS)

.dir-exists%:
	mkdir -p $(@D) && touch $@

test:
	@echo BASE_CHROOT_TARBALLS:
	@for i in $(BASE_CHROOT_TARBALLS); do echo "    $$i"; done


###################################################
# Base chroot tarball rules

admin/ubuntu-keyring.gpg: admin/.dir-exists
	gpg --no-default-keyring --keyring=$(UBUNTU_KEYRING) \
		--keyserver=$(KEYSERVER) --recv-keys \
		--trust-model always $(UBUNTU_KEYID)

# base chroot tarballs are named e.g. lucid/i386/base.tgz
# in this case, $(*D) = lucid; $(*F) = i386
%/base.tgz: admin/ubuntu-keyring.gpg %/aptcache/.dir-exists
	$(SUDO) pbuilder --create --basetgz $@ --buildplace tmp \
	  --distribution $(*D) --architecture $(*F) \
	  --logfile $*/create.log \
	  --mirror $(call MIRROR,$(*D)) \
	  --aptcache $(TOPDIR)/$*/aptcache \
	  $(call DEBOOTSTRAPOPTS,$(*D)) || \
	    rm -f $@ && exit 1

.PHONY:  clean_base_chroot_tarballs
clean_base_chroot_tarballs:
	for codename in $(CODENAMES); do \
	    for arch in $(ARCHES); do \
		rm -f $$codename/base-$$arch.tgz \
		rm -f $$codename/base-$$arch.create.log \
	    done \
	done

###################################################
# Source rules

# clone & update the xenomai submodule
git/.stamp-xenomai: git/.dir-exists
	# be sure the submodule has been checked out
	test -f git/xenomai/.git || \
	    git submodule add -b $(GITBRANCH_XENOMAI) -- $(GITURL_XENOMAI) \
		git/xenomai
	git submodule update git/xenomai
	touch $@

# create the source package
src/.stamp-xenomai: src/.dir-exists git/.stamp-xenomai
	rm -f src/xenomai_*
	cd src && dpkg-source -b $(TOPDIR)/git/xenomai
	touch $@
