#!/bin/sh

if test "$DEBUG"; then
    set -x
fi

echo Resetting Apache Runtime
rm -rf /run/apache2/* /tmp/httpd* /tmp/apache*

if test -s /etc/apache2/envvars; then
    . /etc/apache2/envvars
fi
if test -s /usr/local/bin/nsswrapper.sh; then
    . /usr/local/bin/nsswrapper.sh
fi

. /usr/local/bin/reset-tls.sh
. /usr/local/bin/setupvhosts.sh

echo Cleanup Runtime
env | grep -E '^(PING|PUBLIC|SSL|BACKEND|OIDC|DEBUG)_' \
    | awk -F= '{print $1}' \
    | while read varname
    do
	unset $varname
    done

echo Starting $PROXY_DOMAIN
exec "$@"
