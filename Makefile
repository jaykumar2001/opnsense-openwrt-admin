PLUGIN_NAME=		openwrt-admin
PLUGIN_VERSION=		0.1
PLUGIN_REVISION=	1
PLUGIN_COMMENT=		OpenWrt fleet administration UI
PLUGIN_LICENSE=		BSD2CLAUSE
PLUGIN_MAINTAINER=	jaykumar2005@gmail.com
PLUGIN_WWW=		https://github.com/jaykumar2001/opnsense-openwrt-admin
PLUGIN_TIER=		2

# Note: ../../Mk/plugins.mk resolves only when this repo is nested inside the
# opnsense/plugins monorepo (e.g. net-mgmt/openwrt-admin/). For standalone
# development use 'make test' below and deploy-dev.sh for installation.
test:
	python3 -m unittest discover -s tests -p 'test_*.py'

.include "../../Mk/plugins.mk"
