FROM r2d2bzh/oidc-rp-apache:0.0.0

ARG USERID=1001

ENV PROXY_DOMAIN=example.com \
    PROXY_PORT=8080 \
    PROXY_PROTO=${PROXY_PROTO:-http} \
    DEBIAN_FRONTEND=noninteractive \
    DUMMY_DH_SIZE=2048 \
    PING_PATH=ping

COPY config/* /
RUN set -x \
    && sed -i "/testing/d" /etc/apk/repositories \
    && echo "# Install Apache2.4" \
    && apk add dumb-init ca-certificates gettext libintl apache2-ssl \
    && echo "# Configuring Apache" \
    && mv /do-ssl.conf /no-ssl.conf /kindof-ssl.conf /httpd.conf /etc/apache2/ \
    && mv /auth_openidc.conf /custom-log-fmt.conf /remoteip.conf /ssl.conf \
    /etc/apache2/conf.d/ \
    && mv /setupvhosts.sh /reset-tls.sh /usr/local/bin/ \
    && ln -sf /var/www/html /usr/htdocs \
    && echo "# Fixing permissions" \
    && for dir in /var/www/html /etc/apache2/ssl \
    /etc/apache2/conf.d /etc/apache2/sites-enabled \
    /image-config /runtime-config /var/cache/mod_ssl; \
    do \
    mkdir -p "$dir" \
    && chown -R $USERID:root "$dir" \
    && chmod -R g=u "$dir"; \
    done \
    && mv /proxy-http.conf /proxy-ssl.conf /status.conf /image-config/ \
    && echo "Apache OK" >/var/www/html/index.html \
    && for i in /var/www/html/index.html /etc/ssl/certs \
    /usr/local/share/ca-certificates; \
    do \
    chown -R $USERID:root "$i" \
    && chmod -R g=u "$i"; \
    done \
    && chown -R $USERID:root /var/log/apache2 \
    && ( chmod -R g=u /run /var/log/apache2 || echo nevermind ) \
    && if test "$DUMMY_DH_SIZE" -ge 0 >/dev/null 2>&1; then \
    echo "# Creating Dummy DH Params - this will take some time" \
    && openssl dhparam -out /etc/ssl/dhparam.pem $DUMMY_DH_SIZE \
    && chmod 0444 /etc/ssl/dhparam.pem \
    && chown 0:0 /etc/ssl/dhparam.pem; \
    fi \
    && echo "# Cleaning Up" \
    && rm -rf /usr/share/man /usr/share/doc /var/www/localhost \
    /etc/apache2/conf.d/info.conf /etc/apache2/conf.d/userdir.conf \
    /var/lib/apt/lists/* /usr/share/doc /usr/share/man \
    /nsswrapper.sh /var/lib/apt/lists/*

CMD "/usr/sbin/httpd" "-D" "FOREGROUND"
ENTRYPOINT [ "dumb-init", "--", "/run-apache.sh" ]
HEALTHCHECK --interval=10s --timeout=5s CMD curl -k --connect-timeout 1 --resolve ${PROXY_DOMAIN}:${PROXY_PORT}:127.0.0.1 --fail ${PROXY_PROTO}://${PROXY_DOMAIN}:${PROXY_PORT}/${PING_PATH}/ || exit 1
STOPSIGNAL SIGWINCH
USER $USERID
WORKDIR /var/www/html
