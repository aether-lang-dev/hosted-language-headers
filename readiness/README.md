# readiness: small programs that prove a host can build and run Aether

Run them all with `sh run.sh` (or name some: `sh run.sh hostperl hosttcl`). It
needs `ae` and `aeb` on PATH, and for the `host*` probes the guest languages'
runtime libraries on the machine (a Go toolchain too for `hosttinygo`) and aeb v0.349 or later. Each
probe's output is checked, so a probe that compiles but whose guest language
does not run fails.

**Verified on Aether 0.936.0 with aeb main (v0.349 and later), 2026-11-22 (and on 0.935.0 and 0.933.0 before), on `cachyos` (Linux
x86_64, Python 3.14.10, Lua 5.5.1, Perl 5.44.0, Ruby 3.4.12, Tcl 8.6.16,
Duktape 2.7, Go from the distribution): `sh run.sh` passes all ten probes.**
The probes also ran on macOS arm64 on 2026-11-20 (Aether 0.931.0, aeb from main at v0.347 plus 26
commits, hostpy, hostlua and hostruby as `ae build` runs, since that aeb was
before v0.349) and passed, with the bridge package taken from a local
checkout instead of the pinned tree, and Python 3.13 from Homebrew (the system
Python is 3.9, which the bridge does not support). `hosttinygo` and `aebproj`
also passed there. aeb v0.348 on cachyos failed hostpy, hostlua and hostruby with
E0301 (see below); v0.349 passes them. Nothing here was run on FreeBSD, NetBSD, OpenBSD or Windows.

## Test 1: the bare toolchain (`hello.ae`)

```sh
ae build hello.ae -o hello && ./hello      # prints aether-ready
```

Aetherc, a C compiler, libaether and the standard library work.

## Test 2: an aeb build with dependencies (`aebproj/`)

```
aebproj/                      .aeb         project root marker
  greeter/  greeter_main.ae   .build.ae    leaf node (has main, runnable)
  app/      app.ae            .build.ae    root node: dep("greeter/.build.ae") and imports greeting()
  selftest/ selftest.ae       .tests.ae    a program_test node
```

```sh
cd aebproj && aeb app/.build.ae && ./target/build/app/bin/program   # hello-from-greeter
aeb selftest/.tests.ae                                              # 1/1 PASS
```

Proves aeb drives a multi-node graph: the `dep()` edge, the order, an import
across directories (`import greeter.greeter_main`) and the `target/build/<node>`
layout. Pure Aether, so no other language's toolchain is needed.

## Test 3: Aether running another language (`host*`)

Each probe is a program that runs one line of a guest language through its
bridge and prints a greeting, and its build file uses `aether.program_test`,
which compiles the program and then runs it (`aether.program` would only
compile). The program exits 1 when the guest fails, so a failed load shows as a
failed test; it did not before 2026-11-20.

The bridges are not in the Aether release any more: they live in
[aether-guest-languages](https://github.com/aether-lang-dev/aether-guest-languages),
and each probe's `aether.toml` lists it as a dependency (`ae add
github.com/aether-lang-dev/aether-guest-languages`), imported as `import lua`
and so on. That repository has no tagged releases, so the dependency is its
main branch pinned by the hash of the tree installed on 2026-11-20 (commit
`9212414`). When main has moved, `ae` stops
with "installed as another tree than aether.toml pins": run `ae add
github.com/aether-lang-dev/aether-guest-languages` in the probe's directory to
re-pin.

| Probe | Bridge, on Aether 0.931.0 | Left `contrib/host` in | How it runs here | Greeting |
|---|---|---|---|---|
| `hostpy` | `import python` | 0.887.0 | aeb node | hello from python, hosted by aether |
| `hostlua` | `import lua` | 0.880.0 | aeb node | hello from lua, hosted by aether |
| `hostruby` | `import ruby` | 0.893.0 | aeb node | hello from ruby, hosted by aether |
| `hostperl` | `import perl` | 0.893.0 | aeb node | hello from perl, hosted by aether |
| `hostduktape` | `import duktape` | 0.893.0 | aeb node | hello from duktape, hosted by aether |
| `hosttcl` | `import tcl` | 0.893.0 | aeb node | hello from tcl, hosted by aether |
| `hosttinygo` | `import tinygo`, plus `greet/` | 0.893.0 | aeb node, two nodes | hello from tinygo, hosted by aether, and Add(2,40)=42 Answer()=42 |

No language is without a bridge on 0.931.0: all seven are in
aether-guest-languages.

aeb v0.348 could not build hostpy, hostlua and hostruby as nodes: its own `lib/`
has builder modules named `lua`, `python` and `ruby`, which it put ahead of
installed packages, so `import lua` failed with "Undefined function 'lua.run'".
v0.349 compiles program nodes without its `lib/` on the search path, so they
are nodes like the rest; use v0.349 or later
(`asks/aeb-lib-shadows-guest-language-bridges.md`, resolved).

`hosttinygo` is two nodes: `greet/` compiles `greet.go` into `libgreet.so` with
`aether.tinygo_lib` (which runs the standard `go build -buildmode=c-shared`; the
TinyGo compiler's c-shared mode is wasm only), and the top node, which `dep()`s
it, compiles and runs the program that loads that library by path. A node's
directory is its module, so the two cannot share one.

On the machine that runs a probe, the bridge finds the interpreter's library by
its default name, or by `AETHER_<LANG>_SONAME` when that is set; `run.sh`
sets it for Perl, Python and Ruby (and Lua on macOS) because the default
name is often not present.
