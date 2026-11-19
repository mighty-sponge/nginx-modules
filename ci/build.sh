#!/bin/bash
# Build an nginx dynamic module package with the official nginx/pkg-oss tooling.
# Runs as root inside a clean distro container.
#
# usage: ci/build.sh <pkg-oss ref> <module> <output dir>
set -Eeuo pipefail

ref=$1
module=$2
out=$(realpath -m "$3")
work=$(realpath -m work)

mkdir -p "$out" "$work"
. /etc/os-release

git_clone_pkg_oss() {
    git clone --depth 1 --branch "$ref" https://github.com/nginx/pkg-oss.git "$work/pkg-oss"
}

case "$ID" in
    almalinux|rocky|rhel|centos)
        dnf -y makecache
        dnf -y install epel-release 'dnf-command(config-manager)'
        dnf config-manager --set-enabled crb
        dnf -y install /usr/bin/curl findutils gcc git libxslt make rpm-build which xz
        git_clone_pkg_oss
        cd "$work/pkg-oss/rpm/SPECS"
        make "nginx-module-$module.spec"
        dnf -y builddep "./nginx-module-$module.spec"
        make "module-$module"
        find ../RPMS -type f -name "nginx-module-$module-*.rpm" -exec cp -v {} "$out/" \;
        ;;
    debian|ubuntu)
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y --no-install-recommends \
            build-essential ca-certificates curl devscripts equivs git \
            libxml2-utils lsb-release make xsltproc
        git_clone_pkg_oss
        cd "$work/pkg-oss/debian"
        version=$(make --no-print-directory --eval 'nv:; @echo $(BASE_VERSION)' nv)
        make "rules-module-$module"
        mk-build-deps --install --remove \
            --tool='apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends --yes' \
            "debuild-module-$module/nginx-$version/debian/control"
        make "module-$module"
        # pkg-oss drops the .deb files two levels above debian/
        find "$work" -maxdepth 1 -type f -name "nginx-module-${module}*.deb" -exec cp -v {} "$out/" \;
        ;;
    *)
        echo "unsupported distro: $ID" >&2
        exit 1
        ;;
esac

if ! ls "$out"/nginx-module-"$module"* >/dev/null 2>&1; then
    echo "no packages produced for $module" >&2
    exit 1
fi
ls -l "$out"
