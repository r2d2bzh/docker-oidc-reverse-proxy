# docker-oidc-reverse-proxy
Based on r2d2bzh/docker-oidc-rp-apache with apache set as a reverse proxy


## Deployment requirements
-----------------------

### Keycloak

~~~~~~~~~~~~~~~
In Keycloak, you need to add a new OIDC Client with the following parameters

* *Cliend ID: must match `CLIENT_ID`
* Access Type: *Confidential*
* Standard Flow Enabled: *On*
* Valid Redirect URIs: must match `$PROXY_PROTO://$PROXY_DOMAIN:$PROXY_PORT/oauth2/callback`
* Credentials/Secret: must match `CLIENT_SECRET`
~~~~~~~~~~~~~~~

### FusionDirectory
~~~~~~~~~~~~~~~
You need to configure the following variables in the fusion Directory (stored on ldap):

  fdHttpAuthActivated: FALSE
  fdHttpHeaderAuthActivated: HEADER_AUTH
  fdHttpHeaderAuthHeaderName: REMOTE_USER
~~~~~~~~~~~~~~~
### Environment variables
---------------------

The image recognizes the following environment variables that you can set during
initialization by passing `-e VAR=VALUE` to the Docker `run` command.

The available environment variables can be sorted in several categories:

* Variables that configure the "external", user-facing side of the OIDC proxy
* Variables that configure the connection between the proxy and its (Fusion Directory) backend
* Variables that configure how the proxy interacts with the OpenID Connect Provider (Keycloak)


#### Configuring the user-facing side

|    Variable name             | Default                                   | Description                                                                |
|------------------------------|-------------------------------------------|:---------------------------------------------------------------------------|
|  `PROXY_DOMAIN`              | `example.com`                             | The public hostname that will be used to access the protected application  |
|  `PROXY_PORT`                | `8080`                                    | Port the reverse proxy will listen on. Must be exposed by Docker           |
|  `PROXY_PROTO`               | `http`                                    | On which protocol (`http`/`https`) will connections be accepted            |

#### Connection to the backend server (Fusion Directory)

|    Variable name              | Default                                   | Description                                                               |
|-------------------------------|-------------------------------------------|:--------------------------------------------------------------------------|
|  `BACKEND_HOST`               | `127.0.0.1`                               | Specify the IP/Hostname used to connect ot the backend server             |
|  `BACKEND_PORT`               | undef - would use protocol default        | Specify the port that the backend server is listening on                  |
|  `BACKEND_PROTO`              | `http`                                    | Specify the protocol used by the backend server                           |

#### Connection to the OIDC provider

|    Variable name              | Default                                   | Description
|-------------------------------|-------------------------------------------|:--------------------------------------------------------------------------|
|  `KEYCLOAK_BASE_URL`          | `http://auth.local`                       | Base URL of the Keycloak Server
|  `KEYCLOAK_REALM`             | `test`                                    | Realm in which the application is declared
|  `CLIENT_ID`                  | `changeme`                                | Client ID for the protected application
|  `CLIENT_SECRET`              | `secret`                                  | Client Secret for the protected application
|  `OIDC_CRYPTO_SECRET`         | `secret`                                  | Specify a long, random string that will be used to protect OIDC sessions against tampering on the proxy. This setting is entirely internal to the proxy, and must NOT be known by Keycloak or Fusion Directory


#### Advanced options

|    Variable name              | Default                                   | Description
|-------------------------------|-------------------------------------------|:--------------------------------------------------------------------------|
|  `DEBUG`                      | undef                                     | Toggles Image Debugs
|  `DEBUG_CONFIG`               | undef                                     | Toggles Apache Config Debugs
|  `BACKEND_BASE`               | `/`                                       | Specify a different URL base for the backend application
|  `OIDC_CALLBACK_URL`          | `/oauth2/callback`                        | Specify a different suffix for the proxy's OIDC callback URL
|  `OIDC_REMOTE_USER_CLAIM`     | `preferred_username`                      | Change the name of the claim that contains the username transmitted to the application
|  `OIDC_TOKEN_ENDPOINT_AUTH`   | `client_secret_basic`                     | Change the method used to transmit the Client ID/Secret to the Token endpoint
|  `PING_PATH`                  | `ping`                                    | Change the path of the proxy healthcheck
|  `OIDC_SSL_VERIFY`            | `On`                                      | Enable verification of the OIDC provider's certificate
|  `REMOTE_USER_HEADER`         | `Remote-User`                             | The name of the header containing the authenticated user's login, that the backend application will receive

## Configuring TLS certificates
----------------------------

You can also set the following mount points by passing the `-v /host:/container`
flag to Docker.

### Volume Mounts


|  Volume mount point | Description                   |
|---------------------|-------------------------------|
|  `/certs`           | Apache Certificate (optional) |

Mounting a volume with both `tls.crt` and `tls.key` present would enable Apache
SSL module configuration. Both your proxied VirtualHost and Apache metrics would
be served in https. Otherwise, http would be used.Optionally, a `ca.crt` could
be added as well, for Apache to serve clients with your certificate authorities,
in addition to the server certificate in `tls.crt`.

Other certificate authorities could be added as well - file names must end with
`.crt`. If the `CA` extension is present and enabled, then that certificate
would be added to the container trusted authorities, before starting Apache up.

Running your proxy behind an ingress controller that already implements TLS
termination, you may rather set the `PROXY_PROTO` variable to `https`, without
passing any private key to Apache. This would ensure OIDC login would proceed
using https, using some ingress-configured certificate, while the OIDC proxy
itself does not have access to its key. Adding the chain of trust checking your
OIDC server certificate is however recommended - though we may otherwise set
the `OIDC_SSL_VERIFY=Off` environment variable, to disable IDP TLS verification.