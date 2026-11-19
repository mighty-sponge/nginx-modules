#!/bin/bash
# Functional test for geoip2: country lookups against the MaxMind test database.
set -Eeuo pipefail

MAXMIND_DB_REF=c454a21f31fd17f2843f16094e9afb3a14a42078

work=$(mktemp -d)
curl -fsSL -o "$work/country.mmdb" \
    "https://raw.githubusercontent.com/maxmind/MaxMind-DB/${MAXMIND_DB_REF}/test-data/GeoIP2-Country-Test.mmdb"

cat > "$work/nginx.conf" <<EOF
load_module modules/ngx_http_geoip2_module.so;
load_module modules/ngx_stream_geoip2_module.so;

pid $work/nginx.pid;
error_log stderr notice;

events {}

http {
    access_log off;
    geoip2 $work/country.mmdb {
        \$country default=XX source=\$arg_ip country iso_code;
    }
    server {
        listen 127.0.0.1:8080;
        location / {
            return 200 "\$country";
        }
    }
}

stream {
    geoip2 $work/country.mmdb {
        \$stream_country default=XX source=\$remote_addr country iso_code;
    }
}
EOF

nginx -t -c "$work/nginx.conf"
nginx -c "$work/nginx.conf"
trap 'nginx -c "$work/nginx.conf" -s quit' EXIT

check() {
    local got
    got=$(curl -fsS --retry 5 --retry-connrefused --retry-delay 1 "http://127.0.0.1:8080/?ip=$1")
    if [[ "$got" != "$2" ]]; then
        echo "FAIL: $1 -> '$got', expected '$2'" >&2
        exit 1
    fi
    echo "ok: $1 -> $got"
}

check 81.2.69.160 GB
check 216.160.83.56 US
check 2.125.160.216 GB
check 127.0.0.1 XX
