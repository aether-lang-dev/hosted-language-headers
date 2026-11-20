#!/bin/sh
# Runs every readiness probe and checks what it prints. Needs ae and aeb on PATH
# and the guest languages' runtime libraries on the machine (python3, lua, perl,
# ruby, tcl, duktape; a Go toolchain for hosttinygo). The first run of a host*
# node fetches the aether-guest-languages package (ae add's cache).
#
#   sh run.sh            run them all
#   sh run.sh hostperl   run the named ones
#
# hostpy, hostlua and hostruby are built with `ae build` and run by this script,
# not as aeb nodes: aeb puts its own lua, python and ruby builder modules on the
# compile path ahead of the guest-language bridges of the same names, so an aeb
# node cannot `import lua` (asks/aeb-lib-shadows-guest-language-bridges.md).
cd "$(dirname "$0")" || exit 1

# libperl is not on the loader's default path on most systems (it lives under
# perl's CORE directory), so say where it is, as perl/README.md does.
if [ -z "$AETHER_PERL_SONAME" ] && command -v perl >/dev/null 2>&1; then
    AETHER_PERL_SONAME=$(perl -MConfig -e 'for my $d ("$Config{archlibexp}/CORE", split " ", $Config{libpth}) { my $f = "$d/$Config{libperl}"; if (-f $f) { print $f; last } }')
    export AETHER_PERL_SONAME
fi
# Python and Ruby: the loader's default names (libpython3.so, libruby.so) are
# often absent, notably on macOS, so name the library the interpreter itself
# was built with (python/README.md and ruby/README.md give these lines; for a macOS
# framework Python the INSTSONAME join is not a file, so the framework's own
# Python binary, one directory up from LIBDIR, is used).
if [ -z "$AETHER_PYTHON_SONAME" ] && command -v "${PYTHON:-python3}" >/dev/null 2>&1; then
    AETHER_PYTHON_SONAME=$("${PYTHON:-python3}" -c 'import sysconfig as s, os; d = s.get_config_var("LIBDIR"); p = os.path.join(d, s.get_config_var("INSTSONAME")); print(p if os.path.exists(p) else os.path.normpath(os.path.join(d, "..", "Python")))')
    export AETHER_PYTHON_SONAME
fi
if [ -z "$AETHER_RUBY_SONAME" ] && command -v ruby >/dev/null 2>&1; then
    AETHER_RUBY_SONAME=$(ruby -rrbconfig -e 'puts File.join(RbConfig::CONFIG["libdir"], RbConfig::CONFIG["LIBRUBY_SO"])')
    export AETHER_RUBY_SONAME
fi
# Lua has no query of its own: on macOS take Homebrew's, elsewhere the default
# name (liblua.so) is left for the bridge to find.
if [ -z "$AETHER_LUA_SONAME" ] && command -v brew >/dev/null 2>&1 && [ -f "$(brew --prefix lua 2>/dev/null)/lib/liblua.dylib" ]; then
    AETHER_LUA_SONAME="$(brew --prefix lua)/lib/liblua.dylib"
    export AETHER_LUA_SONAME
fi
fail=0
ok()  { echo "PASS $1"; }
bad() { echo "FAIL $1"; fail=1; }

# expect NAME OUTPUT WANT: OUTPUT must contain WANT
expect() {
    case "$2" in
        *"$3"*) echo "$2" | grep -F "$3"; ok "$1" ;;
        *) echo "$2" | tail -20; bad "$1 (missing: $3)" ;;
    esac
}

probe_hello() {
    out=$(ae build hello.ae -o target-hello 2>&1 && ./target-hello) || { echo "$out" | tail; bad hello; return; }
    rm -f target-hello
    expect hello "$out" "aether-ready"
}

probe_aebproj() {
    ( cd aebproj && aeb app/.build.ae >/dev/null 2>&1 ) || { bad "aebproj app (aeb)"; return; }
    expect "aebproj app" "$(cd aebproj && ./target/build/app/bin/program)" "hello-from-greeter"
    ( cd aebproj && aeb selftest/.tests.ae 2>&1 | grep -E "PASS|FAIL" ) | grep -q "1/1 PASS" && ok "aebproj selftest" || bad "aebproj selftest"
}

# aeb node: run aeb in the node's directory, then read the program's output
# from the node's log (aeb prints it only on failure).
probe_aeb() {
    n=$1; want=$2
    out=$(cd "$n" && aeb .build.ae 2>&1); rc=$?
    log=$(cat "$n/target/.aeb/logs/..log" 2>/dev/null)
    if [ $rc -ne 0 ]; then echo "$out" | tail -20; bad "$n (aeb)"; return; fi
    expect "$n" "$log" "$want"
}

# direct: build with ae build, run the binary
probe_direct() {
    n=$1; want=$2
    mkdir -p "$n/target"
    out=$(cd "$n" && ae build "$n.ae" -o "target/$n" 2>&1 && "./target/$n") || { echo "$out" | tail -20; bad "$n (ae build)"; return; }
    expect "$n" "$out" "$want"
}

sel="${*:-all}"
has() { for a in $sel; do [ "$a" = all ] || [ "$a" = "$1" ] && return 0; done; return 1; }

has hello      && probe_hello
has aebproj    && probe_aebproj
has hostpy     && probe_direct hostpy     "hello from python, hosted by aether"
has hostlua    && probe_direct hostlua    "hello from lua, hosted by aether"
has hostruby   && probe_direct hostruby   "hello from ruby, hosted by aether"
has hostperl   && probe_aeb hostperl      "hello from perl, hosted by aether"
has hostduktape && probe_aeb hostduktape  "hello from duktape, hosted by aether"
has hosttcl    && probe_aeb hosttcl       "hello from tcl, hosted by aether"
has hosttinygo && probe_aeb hosttinygo    "Add(2,40)=42  Answer()=42"
exit $fail
