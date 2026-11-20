# aeb's lua, python and ruby builder modules shadow the guest-language bridges

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
the last is the narrowest. Until then
`hosted-language-headers/readiness/run.sh` builds hostpy, hostlua and hostruby
with `ae build` instead of as aeb nodes.
