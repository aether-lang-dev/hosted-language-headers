# hosted-language-headers

Captured C headers for the languages Aether's guest-language bridges embed
(Python, Lua, Perl, Ruby, Duktape), plus per-target configured-header overlays
(`targets/`) and a `readiness/` directory of small programs that prove a host
can build and run those bridges (see `readiness/README.md`).

## Who uses the headers today: nobody we can find

Checked 2026-11-20 against Aether 0.931.0 and the sibling repositories in the
family:

- The [`aether-builder` image](https://github.com/aether-lang-dev/aether/tree/main/tools/docker)
  stopped cloning this repository in Aether 0.210.0 (the captured `pyconfig.h`,
  `luaconf.h` and `perl.h` are distro build products that name paths only the
  matching `-dev` package supplies), and its `--with=<lang>` layers and `WITH_*`
  build arguments were removed in 0.893.0.
- The bridges themselves left Aether's `contrib/host/` (Lua in 0.880.0, Python
  in 0.887.0, Duktape, Perl, Ruby, Tcl, TinyGo and the rest in 0.893.0) for
  [aether-guest-languages](https://github.com/aether-lang-dev/aether-guest-languages).
  Each bridge there carries its own small ABI header (`lua_abi.h`,
  `python_abi.h`, `perl_abi.h`, `ruby_abi.h`, `duktape_abi.h`, `tcl_abi.h`)
  declaring the few language types it uses, and `dlopen`s the interpreter at
  run time, so a program that imports one builds without any of the trees here.
- `aether-crossbuild` stages Lua and Duktape headers from the upstream release
  tarballs (Lua 5.4.7, Duktape 2.7.0), not from this repository.

The trees stay because the `targets/` overlays and the captured versions are a
record of what each platform's configured headers look like, and nothing has
been removed on the strength of the search above alone. If you find a consumer,
say so here.

## Layout

```
python/         Python 3.11.2 headers (Python.h and what it pulls in; no pyconfig.h:
                that comes from targets/<triple>/python/)
lua/            Lua 5.4.4 headers (lua.h, lauxlib.h, lualib.h, luaconf.h)
perl/           Perl 5.36.0 CORE/ headers (EXTERN.h, perl.h, ~80 files)
ruby/           Ruby 3.1.2 portable headers (ruby.h and tree)
ruby-arch/      Ruby 3.1.2 platform-specific headers (ruby/config.h)
js/             Duktape 2.7.0 headers (duktape.h + duk_config.h)
targets/        per-platform configured headers and, for FreeBSD, a full Ruby 3.4 tree
readiness/      the probes; run them with `sh readiness/run.sh`
```

Sizes (committed, `du -sh`):

| Tree      | Size    |
|-----------|---------|
| python    | ~1.2 MB |
| lua       | ~56 KB  |
| perl      | ~7.8 MB |
| ruby      | ~1.9 MB |
| ruby-arch | ~1.2 MB |
| js        | ~200 KB |
| targets   | ~2.1 MB |

## Per-OS / per-arch

The shared trees are linux-x86_64-glibc, captured from Debian 12 (bookworm).
`PLATFORM.md` has the package versions and says which files are
platform-sensitive. The files that differ per platform are kept per target
triple under `targets/` (see `targets/README.md`), which replaced an earlier
plan of one git branch per platform: a cross-build needs every target at once.

## Usage

Clone this repository and point the toolchain at the tree you need, with a
target overlay first when you are not building for Debian x86_64, for example
`-Itargets/x86_64-macos/python -Ipython`. Whether a bridge needs it at all is
the question the section above answers: those in aether-guest-languages do not.

## Licensing

Each language's headers are licensed under that language's
own license:

| Language | License |
|----------|---------|
| Python   | Python Software Foundation License (PSFL) |
| Lua      | MIT |
| Perl     | Artistic License / GPL (dual) |
| Ruby     | BSD-2-Clause + Ruby License (dual) |
| duktape  | MIT |

All five permit redistribution of source files with attribution.
The headers' upstream copyright / license notices are preserved
inside the files themselves (the `Copyright …` blocks at the top
of `Python.h`, `lua.h`, `EXTERN.h`, `ruby.h`, `duktape.h`); no
extra `LICENSE` files are added at the repo level.

## How the headers were captured

```bash
sudo apt install -y --no-install-recommends \
    python3-dev liblua5.4-dev libperl-dev ruby-dev duktape-dev

# Python
PY_INCDIR="$(python3 -c 'import sysconfig; print(sysconfig.get_path("include"))')"
cp -r "$PY_INCDIR/." python/

# Lua
cp /usr/include/lua5.4/*.h lua/

# Perl
PERL_INCLUDE="$(perl -MConfig -e 'print $Config{archlibexp}')/CORE"
cp -r "$PERL_INCLUDE/." perl/

# Ruby (two trees — portable + arch-specific)
RUBY_HDRDIR="$(ruby -rrbconfig -e 'print RbConfig::CONFIG["rubyhdrdir"]')"
RUBY_ARCHHDRDIR="$(ruby -rrbconfig -e 'print RbConfig::CONFIG["rubyarchhdrdir"]')"
cp -r "$RUBY_HDRDIR/." ruby/
cp -r "$RUBY_ARCHHDRDIR/." ruby-arch/

# duktape
cp /usr/include/duktape.h /usr/include/duk_config.h js/

# the one configured header the shared tree does not keep
mv python/pyconfig.h targets/x86_64-linux-gnu/python/
```

## What's NOT here

- **Java, Go, TinyGo, Factor, QuickJS, Racket.** No captured headers:
  the Java bridge uses a prebuilt jar and a JRE, the Go and TinyGo bridges load
  a library built with `go build -buildmode=c-shared` and include no Go header,
  the Factor bridge is pure `dlopen` against the embed-api fork's `libfactor`
  (`aether-lang-dev/factor-language`) and `factor.image`, and the QuickJS bridge
  uses aether's `contrib.quickjs`. All of these bridges live in
  aether-guest-languages.
- **Tcl headers.** Tcl 8.6 has a bridge in aether-guest-languages
  (`tcl/tcl_abi.h`), but no tree here: it was never captured.
- **Runtime shared libraries** (`libpython3.so`, `libruby.so`, `liblua5.4.so`,
  and so on). Those come from the machine's package manager, on the machine
  that runs the program.
