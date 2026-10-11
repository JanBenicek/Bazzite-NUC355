.PHONY: build check

build:
	podman build --pull=newer -t localhost/bazzite-n355:latest .

check:
	shellcheck build_files/build.sh setup-user.sh system_files/usr/local/bin/n355-media-check
