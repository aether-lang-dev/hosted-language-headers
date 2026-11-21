# aeb's lua, python and ruby builder modules shadow the guest-language bridges

**RESOLVED in aeb v0.349** (2026-11-21): program nodes are compiled without aeb's
`lib/` on their search path; aeb's reply is `asks/REPLY-lib-shadows-guest-language-bridges.md`
in the aeb repo. Checked here: hostpy, hostlua and hostruby fail with the E0301
below on v0.348 and pass as aeb nodes on v0.349 (cachyos, Aether 0.931.0).

Found 2026-11-20 on Aether 0.931.0 with aeb v0.348 (Linux x86_64).

## What happens

`aether-guest-languages` exports bridge modules named `lua`, `python` and
`ruby` (and `go`, `java`, ...). aeb's own `lib/` holds builder modules with the
same names (`lib/lua`, `lib/python`, `lib/ruby`, `lib/go`, `lib/java`). When aeb
compiles an `aether.program` or `aether.program_test` node it passes `--lib
<aeb>/lib` to `ae build`, and a `--lib` entry is searched before an installed
dependency, so `import lua` in the program finds aeb's builder module and the
bridge is never seen:

    error[E0301]: Undefined function 'lua.run'
    error[E0301]: Undefined function 'lua.finalize'

The same program builds and runs with plain `ae build`, which has no `--lib`.
`perl`, `duktape`, `tcl` and `tinygo` do not collide (aeb has no module of
those names), and their nodes pass.

## Repro

```sh
mkdir hostlua && cd hostlua && touch .aeb
cat > hostlua.ae <<'AE'
import lua

main() {
    lua.run("print('hello from lua, hosted by aether')")
    lua.finalize()
}
AE
cat > .build.ae <<'AE'
import bldr
import aether

aeb(cap) {
    bldr.build() {
        aether.program_test() {
            source("hostlua.ae")
        }
    }
}
AE
ae add github.com/aether-lang-dev/aether-guest-languages
ae build hostlua.ae -o target/x && ./target/x     # prints the hello line
aeb .build.ae                                      # E0301 Undefined function 'lua.run'
```

Narrowed to `ae`: `ae build hostlua.ae --lib <aeb>/lib` gives the same error.

## What would fix it

Any one of: aeb's builder modules take names that cannot clash with a language
(`luabuild`, `pythonbuild`, ...), or aeb passes its lib after the project's
dependencies, or a node can say that its program imports a package's module in
preference to aeb's. The first is a rename across every aeb SDK and its users;
the last is the narrowest. (aeb took the narrowest. Until then readiness/run.sh built the three with `ae build`; it no longer does.)
