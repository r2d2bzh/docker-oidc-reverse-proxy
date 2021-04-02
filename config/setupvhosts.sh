PROXY_DOMAIN=${PROXY_DOMAIN:-example.com}
SSL_INCLUDE=${SSL_INCLUDE:-no-ssl}

if test -s /etc/apache2/sites-enabled/000-servername.conf; then
    echo Skipping ServerName generation - already initialized
else
    echo Initializing ServerName
    echo ServerName ${HOSTNAME:-apache} \
	>/etc/apache2/sites-enabled/000-servername.conf
fi

if test -s /etc/apache2/sites-enabled/001-listen.conf; then
    echo Skipping Bind Ports generation - already initialized
else
    echo Initializing Bind Ports
    echo Listen $PROXY_PORT \
	>/etc/apache2/sites-enabled/001-listen.conf
fi

if test -s /etc/apache2/sites-enabled/003-proxy.conf; then
    echo Skipping VirtualHost generation - already initialized
else
    echo Initializing VirtualHost
    export REMOTE_USER_HEADER=${REMOTE_USER_HEADER:-Remote-User}
    export BACKEND_BASE=${BACKEND_BASE:-/}
    export BACKEND_HOST=${BACKEND_HOST:-127.0.0.1}
    export BACKEND_PORT=${BACKEND_PORT:-}
    export BACKEND_PROTO=${BACKEND_PROTO:-http}
    export OIDC_CALLBACK_URL=${OIDC_CALLBACK_URL:-/oauth2/callback}
    export CLIENT_ID=${CLIENT_ID:-changeme}
    export CLIENT_SECRET=${CLIENT_SECRET:-secret}
    export OIDC_CRYPTO_SECRET=${OIDC_CRYPTO_SECRET:-secret}
    export KEYCLOAK_BASE_URL=${KEYCLOAK_BASE_URL:-http://auth.local}
    export KEYCLOAK_REALM=${KEYCLOAK_REALM:-test}
    export OIDC_REMOTE_USER_CLAIM=${OIDC_REMOTE_USER_CLAIM:-preferred_username}
    export OIDC_SSL_VERIFY=${OIDC_SSL_VERIFY:-On}
    export OIDC_TOKEN_ENDPOINT_AUTH=${OIDC_TOKEN_ENDPOINT_AUTH:-client_secret_basic}

    CALLBACK_ROOT_SUB_COUNT=`echo $OIDC_CALLBACK_URL | awk -F/ '{print NF}'`
    CALLBACK_ROOT_SUB_COUNT=`expr $CALLBACK_ROOT_SUB_COUNT - 2 2>/dev/null`
    if ! test "$CALLBACK_ROOT_SUB_COUNT" -ge 2; then
	CALLBACK_ROOT_SUB_COUNT=2
    fi
    export CALLBACK_ROOT_URL=`echo $OIDC_CALLBACK_URL | cut -d/ -f 2-$CALLBACK_ROOT_SUB_COUNT`
    if test "$BACKEND_PROTO" = https; then
	if test -s /runtime-config/proxy-ssl.conf; then
	    USE_TEMPLATE=/runtime-config/proxy-ssl.conf
	else
	    USE_TEMPLATE=/image-config/proxy-ssl.conf
	fi
    else
	if test -s /runtime-config/proxy-http.conf; then
	    USE_TEMPLATE=/runtime-config/proxy-http.conf
	else
	    USE_TEMPLATE=/image-config/proxy-http.conf
	fi
    fi
    if test "$BACKEND_PORT"; then
	export BACKEND_PORTSUFFIX=":$BACKEND_PORT"
    fi

    envsubst <"$USE_TEMPLATE" >/etc/apache2/sites-enabled/003-proxy.conf

    if test "$DEBUG_CONFIG"; then
	echo "============================================="
	echo "=== Following Configuration was Generated ==="
	echo "============================================="
	echo ""
	sed -e "s|OIDCClientSecret .*|OidcClientSecret <redacted>|" \
	    -e "s|OIDCCryptoPassphrase .*|OidcCryptoPassphrase <redacted>|" \
	    /etc/apache2/sites-enabled/003-proxy.conf
	echo ""
	echo "============================================="
	echo "============================================="
    fi
fi

echo Installing Status VirtualHost on Loopback
test "$SSL_INCLUDE" = do-ssl || SSL_INCLUDE=no-ssl
if test -s /runtime-config/status.conf; then
    envsubst </runtime-config/status.conf
else
    envsubst </image-config/status.conf
fi >/etc/apache2/sites-enabled/999-status.conf
