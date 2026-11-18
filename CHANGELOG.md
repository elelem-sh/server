# Changelog

## [0.2.2](https://github.com/elelem-sh/server/compare/v0.2.1...v0.2.2) (2026-11-18)


### Bug Fixes

* **deps:** accept the json that Ruby 4.0 ships ([3b4c161](https://github.com/elelem-sh/server/commit/3b4c1613d604799dd5813a4d5dafd2bcde88a824))

## [0.2.1](https://github.com/elelem-sh/server/compare/v0.2.0...v0.2.1) (2026-11-15)


### Bug Fixes

* build a Session for Config.apply and Agent#turn ([4ab731c](https://github.com/elelem-sh/server/commit/4ab731c02948dfd0c49d1750e680fea0e9b7de75))
* correlate prompt/answer by id, close /answer pre-approval bug ([ddae723](https://github.com/elelem-sh/server/commit/ddae723c67ef2a44de4a50869f7cbaeab13c9b66))
* each browser tab gets its own session, and slash commands run as commands ([elelem-sh/elelem.sh#31](https://github.com/elelem-sh/elelem.sh/issues/31)) ([31a6d96](https://github.com/elelem-sh/server/commit/31a6d965704d7faceb23d143f37dbc58dfae4609))
* require elelem ~&gt; 0.12, the floor builtins/skills actually need ([af2fdac](https://github.com/elelem-sh/server/commit/af2fdac0462ed4774fbb136361502f60555e05bc))
* server prompt ids are unique across tabs, a claimed tab cannot be evicted, and a closed tab keeps its place for a minute ([aedcf3c](https://github.com/elelem-sh/server/commit/aedcf3c4565ef18e2c48914abc9dc7c5ece08a72))
* server tabs build without blocking others, free idle places, survive a reload mid-prompt, and keep the token out of the address bar ([163433d](https://github.com/elelem-sh/server/commit/163433d85a5acd3eba7c891bedabc034f455b144))
* the server answers a bound IPv6 address, and ends a turn before taking the next ([f453fd2](https://github.com/elelem-sh/server/commit/f453fd293985781446d167ea110eb3249ce56cda))
* the server defaults to the demo provider, since elelem 0.13.1 removed stub ([e7867bc](https://github.com/elelem-sh/server/commit/e7867bc63e9f13a18cadaae5f51e9c8fc945533e))
* the server listens on 127.0.0.1 and refuses other hosts, origins and non-JSON posts ([elelem-sh/elelem.sh#1](https://github.com/elelem-sh/elelem.sh/issues/1)) ([54197c4](https://github.com/elelem-sh/server/commit/54197c442ae08cc62c3e5e82d54e2ea4efce892b))
* the server requires the token it prints at start ([elelem-sh/elelem.sh#1](https://github.com/elelem-sh/elelem.sh/issues/1)) ([c76e69c](https://github.com/elelem-sh/server/commit/c76e69c3d8e96e671fe9c8c577863bd0fc41668a))
* the server runs one turn at a time and the page waits for it ([elelem-sh/elelem.sh#31](https://github.com/elelem-sh/elelem.sh/issues/31)) ([a7fc5d6](https://github.com/elelem-sh/server/commit/a7fc5d6a48113bb53759ef24bc292cd9ce9caafe))
* the startup line brackets an IPv6 address so the URL works ([641a803](https://github.com/elelem-sh/server/commit/641a8034fdc1d0763150fa01ed76d7ae52a0376d))
* the web page renders line breaks, code and bold ([elelem-sh/elelem.sh#30](https://github.com/elelem-sh/elelem.sh/issues/30)) ([d29df97](https://github.com/elelem-sh/server/commit/d29df971dcbc0eb8d8c5b32d7a9b8c2816deffbd))
