should_rehash=false

for check in $(ls /certs/*.crt \
		  /run/secrets/kubernetes.io/serviceaccount/ca.crt \
		  2>/dev/null || true)
do
    if test -s $check; then
	if ! openssl x509 -text -noout -in "$check" 2>/dev/null \
		| grep CA:TRUE >/dev/null; then
	    echo NOTICE: skipping $check, not a certificate authority
	    continue
	fi
	if test -d /etc/pki/ca-trust/source/anchors; then
	    dir=/etc/pki/ca-trust/source/anchors
	else
	    dir=/usr/local/share/ca-certificates
	fi
	f=`basename $check`
	if ! test -s /usr/local/share/ca-certificates/runtime-$f.crt; then
	    if ! cat $check >/usr/local/share/ca-certificates/runtime-$f.crt; then
		echo WARNING: failed adding $check to certificate authorities >&2
	    else
		should_rehash=true
	    fi
	fi
    fi
done

if $should_rehash; then
    if ! update-ca-certificates; then
	echo WARNING: failed updating trusted certificate authorities >&2
    fi
fi
unset should_rehash

if test -s /etc/apache2/ssl/dhserver-full.crt -a \
	-s /etc/apache2/ssl/server.key -a \
	"$RESET_SSL" = false; then
    echo Skipping Apache SSL configuration - already initialized
    export SSL_INCLUDE=do-ssl
elif test -s /certs/tls.key -a -s /certs/tls.crt; then
    echo Initializing Apache SSL configuration
    if ! test -s /certs/dhparam.pem; then
	if ! test -s /etc/ssl/dhparam.pem; then
	    echo No DH found alongside server certificate key pair, generating one
	    echo This may take some time...
	    if ! openssl dhparam -out /etc/apache2/ssl/dhparam.pem \
		    ${DUMMY_DH_SIZE:-1024}; then
		echo WARNING: Failed generating DH params
		rm -f /etc/apache2/ssl/dhparam.pem
		touch /etc/apache2/ssl/dhparam.pem
	    fi
	else
	    ln -sf /etc/ssl/dhparam.pem /etc/apache2/ssl/
	fi
    else
	ln -sf /certs/dhparam.pem /etc/apache2/ssl/
    fi
    if ! test -s /certs/ca.crt; then
	if ! test -s /run/secrets/kubernetes.io/serviceaccount/ca.crt; then
	    cat <<EOT >&2
WARNING: Looks like there is no CA chain defined!
	 assuming it is not required or otherwise included in server
	 certificate definition
EOT
	    rm -f /etc/apache2/ssl/ca.crt
	    touch /etc/apache2/ssl/ca.crt
	else
	    ln -sf /run/secrets/kubernetes.io/serviceaccount/ca.crt /etc/apache2/ssl/
	fi
    else
	ln -sf /certs/ca.crt /etc/apache2/ssl/
    fi
    cat /certs/tls.crt >/etc/apache2/ssl/server.crt
    cat /etc/apache2/ssl/server.crt /etc/apache2/ssl/ca.crt \
	>/etc/apache2/ssl/dhserver-full.crt 2>/dev/null
    cat /certs/tls.key >/etc/apache2/ssl/server.key
    chmod 0640 /etc/apache2/ssl/server.key
    export SSL_INCLUDE=do-ssl
elif test "$PROXY_PROTO" = https; then
    export SSL_INCLUDE=kindof-ssl
else
    export SSL_INCLUDE=no-ssl
fi
