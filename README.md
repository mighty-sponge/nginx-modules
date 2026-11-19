# nginx-modules

Third-party dynamic modules packaged for the **official nginx.org packages**
(`nginx` from `https://nginx.org/packages/`), for RedHat- and Debian-based
distributions.

nginx itself is not built here: install it from the nginx.org repository and
add the module package from this repository's releases.

## How it works

- Packaging recipes come from [nginx/pkg-oss](https://github.com/nginx/pkg-oss),
  the same tooling nginx.org uses for its own packages. The tag in
  [`PKG_OSS_REF`](PKG_OSS_REF) (e.g. `1.30.7-1`) pins the nginx version, the
  module source versions and their SHA512 checksums.
- [`MODULES`](MODULES) lists the modules to build, by their pkg-oss names
  (`rpm/SPECS/Makefile.module-<name>`).
- Every module is built in a clean container per distro and architecture:

  | family | images | arch |
  |---|---|---|
  | RedHat | `almalinux:9`, `almalinux:10` | amd64, arm64 |
  | Debian | `debian:bookworm`, `debian:trixie`, `ubuntu:jammy`, `ubuntu:noble` | amd64, arm64 |

- After the build, the official nginx of the same version is installed from
  nginx.org together with the fresh package, every shipped `.so` is loaded with
  `nginx -t`, and `tests/<module>.sh` runs if present.

Packages depend on `nginx-r<version>`, which only the matching official nginx
package provides, so a module can't be installed against a different nginx
version.

## Releases

Package names follow nginx.org conventions:

```
nginx-module-geoip2-1.30.7+3.4-1.el9.ngx.x86_64.rpm
nginx-module-geoip2_1.30.7+3.4-1~trixie_amd64.deb
```

`SHA256SUMS` is attached to every release.

To release a new nginx version:

1. Set `PKG_OSS_REF` to the new pkg-oss tag (see `git ls-remote --tags https://github.com/nginx/pkg-oss`).
2. Push to `main` and wait for the build to pass.
3. Tag the commit with exactly the same name and push the tag:
   ```sh
   git tag 1.30.7-1 && git push origin 1.30.7-1
   ```

The release job runs only for tags and refuses a tag that differs from
`PKG_OSS_REF`.

## Adding a module

1. Make sure pkg-oss has a recipe for it: `rpm/SPECS/Makefile.module-<name>` and `debian/Makefile.module-<name>`.
2. Add `<name>` to `MODULES`.
3. Optionally add `tests/<name>.sh` with a functional check; it runs as root
   with the official nginx and the module already installed.

## Local build

```sh
docker run --rm -v "$PWD:/src" -w /src almalinux:9 bash -c \
  'bash ci/build.sh "$(cat PKG_OSS_REF)" geoip2 dist && bash ci/test.sh "$(cat PKG_OSS_REF)" geoip2 dist'
```

Packages end up in `dist/`.
