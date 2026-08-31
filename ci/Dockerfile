# Pinned cloud build environment for this template.
#
# Base image: barichello/godot-ci, pinned by immutable digest (not a mutable
# tag) so the build environment can never silently drift. This tag corresponds
# to Godot 4.7.2 and bundles: the Godot 4.7.2 Linux headless editor, matching
# Android export templates, Android SDK + NDK + build-tools, and a JDK — the
# full toolchain needed for a headless `--export-debug`/`--export-release`
# Android build. See docs/ARCHITECTURE.md section 2 for the rationale.
#
# To bump the engine version: update GODOT_VERSION below, re-resolve the
# digest for that tag (`docker buildx imagetools inspect barichello/godot-ci:<version>`),
# and update project.godot / export_presets.cfg to match if needed.
FROM barichello/godot-ci@sha256:cdcca31e9194fd59a68a63f4b1b9c3981716819c520cd6f7966c5d72ca7246bd

# Documents the pinned version for humans inspecting the image; the digest
# above is the actual source of truth used by the CI workflow.
LABEL org.opencontainers.image.description="Godot 4.7.2 + Android SDK/NDK — pinned mobile template build environment"
ENV GODOT_VERSION=4.7.2
