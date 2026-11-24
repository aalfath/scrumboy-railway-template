# Changelog

## 3.42.0 (2026-11-24)

- First release: Scrumboy [v3.42.0](https://github.com/markrai/scrumboy/releases/tag/v3.42.0), image `ghcr.io/markrai/scrumboy:3.42.0@sha256:d9605646359c76d59be2164b3806203ed7cdb83c55a54131904fccd723dbc5c3`.
- Owner account created on a loopback-only listener before the public port opens; a changed `SCRUMBOY_OWNER_PASSWORD` is applied on the next boot.
- Encryption key generated once and kept on the `/data` volume.
