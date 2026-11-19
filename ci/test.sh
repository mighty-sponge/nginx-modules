#!/bin/bash
# Install the official nginx.org nginx of the matching version plus the built
# module package, check that every shipped .so loads, then run tests/<module>.sh.
# Runs as root inside a clean distro container.
#
# usage: ci/test.sh <pkg-oss ref> <module> <package dir>
set -Eeuo pipefail

ref=$1
module=$2
dir=$(realpath "$3")
here=$(dirname "$(realpath "$0")")

version=${ref%-*}
release=${ref##*-}
# odd minor versions live in the mainline repo
branch=
if (( $(cut -d. -f2 <<<"$version") % 2 )); then
    branch=mainline/
fi

. /etc/os-release

case "$ID" in
    almalinux|rocky|rhel|centos)
        cat > /etc/yum.repos.d/nginx.repo <<EOF
[nginx]
name=nginx.org
baseurl=https://nginx.org/packages/${branch}rhel/${VERSION_ID%%.*}/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF
        dnf -y install /usr/bin/curl "nginx-$version-$release.el${VERSION_ID%%.*}.ngx"
        dnf -y install "$dir"/nginx-module-"$module"-[0-9]*.rpm
        so_files=$(rpm -ql "nginx-module-$module" | grep '\.so$' | grep -v -- '-debug\.so$')
        ;;
    debian|ubuntu)
        export DEBIAN_FRONTEND=noninteractive
        # containers have no init: keep package scripts from starting nginx
        printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
        chmod +x /usr/sbin/policy-rc.d
        apt-get update
        apt-get install -y --no-install-recommends ca-certificates curl
        curl -fsSL https://nginx.org/keys/nginx_signing.key -o /usr/share/keyrings/nginx.asc
        echo "deb [signed-by=/usr/share/keyrings/nginx.asc] https://nginx.org/packages/${branch}${ID} ${VERSION_CODENAME} nginx" \
            > /etc/apt/sources.list.d/nginx.list
        apt-get update
        apt-get install -y --no-install-recommends "nginx=${version}-${release}~${VERSION_CODENAME}"
        apt-get install -y --no-install-recommends "$dir"/nginx-module-"$module"_*.deb
        so_files=$(dpkg -L "nginx-module-$module" | grep '\.so$' | grep -v -- '-debug\.so$')
        ;;
    *)
        echo "unsupported distro: $ID" >&2
        exit 1
        ;;
esac

nginx -V

echo "=== load test"
conf=$(mktemp)
{
    for so in $so_files; do
        echo "load_module $so;"
    done
    echo "events {}"
} > "$conf"
cat "$conf"
nginx -t -c "$conf"

if [[ -f "$here/../tests/$module.sh" ]]; then
    echo "=== tests/$module.sh"
    bash "$here/../tests/$module.sh"
fi
