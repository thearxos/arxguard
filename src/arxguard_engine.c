#include "arxguard_engine.h"
#include "arxguard_simd.h"
#include <string.h>

static void add(struct arxguard_result *r, int sev, const char *reason) {
    if (r->findings < 24) {
        r->finding[r->findings].severity = sev;
        r->finding[r->findings].reason = reason;
        r->findings++;
    }
    if (sev == ARXGUARD_BLOCK) r->code = ARXGUARD_BLOCK;
    else if (sev == ARXGUARD_WARN && r->code == ARXGUARD_CLEAN) r->code = ARXGUARD_WARN;
}

static int has(const unsigned char *s, size_t n, const char *p) {
    size_t m = strlen(p);
    if (!m || m > n) return 0;
    for (size_t i = 0; i + m <= n; ++i)
        if (s[i] == (unsigned char)p[0] && !memcmp(s + i, p, m)) return 1;
    return 0;
}

static int ci(unsigned char c) { return c >= 'A' && c <= 'Z' ? c + 32 : c; }

static int has_ci(const unsigned char *s, size_t n, const char *p) {
    size_t m = strlen(p);
    if (!m || m > n) return 0;
    for (size_t i = 0; i + m <= n; ++i) {
        size_t j = 0;
        for (; j < m; ++j) if (ci(s[i + j]) != ci((unsigned char)p[j])) break;
        if (j == m) return 1;
    }
    return 0;
}

static int word(const unsigned char *s, size_t n, const char *p) {
    size_t m = strlen(p);
    for (size_t i = 0; i + m <= n; ++i) {
        unsigned char a = i ? s[i - 1] : 0, b = i + m < n ? s[i + m] : 0;
        if ((a >= 'a' && a <= 'z') || (a >= 'A' && a <= 'Z') || a == '_' || a == '-') continue;
        if (memcmp(s + i, p, m)) continue;
        if ((b >= 'a' && b <= 'z') || (b >= 'A' && b <= 'Z') || b == '_' || b == '-') continue;
        return 1;
    }
    return 0;
}

static int flag(const unsigned char *s, size_t n, const char *p) {
    size_t m = strlen(p);
    for (size_t i = 0; i + m <= n; ++i) {
        if (memcmp(s + i, p, m)) continue;
        unsigned char a = i ? s[i - 1] : 0, b = i + m < n ? s[i + m] : 0;
        if ((i == 0 || a == ' ' || a == '\t' || a == '\n' || a == '\r') &&
            (i + m == n || b == ' ' || b == '\t' || b == '\n' || b == '\r')) return 1;
    }
    return 0;
}

static int destructive(const unsigned char *s, size_t n) {
    return has_ci(s, n, "rm -rf /") || has_ci(s, n, "rm -fr /") ||
           has_ci(s, n, "rm -rf ~") || has_ci(s, n, "rm -rf .") ||
           has_ci(s, n, "rm --recursive --force /") || has_ci(s, n, "of=/dev/sda") ||
           has_ci(s, n, "of=/dev/nvme") || has_ci(s, n, "of=/dev/vda") ||
           has_ci(s, n, "of=/dev/mmcblk") || has_ci(s, n, "mkfs /dev/") ||
           has_ci(s, n, "wipefs") || has(s, n, ":(){ :|:& };:");
}

static int reverse_shell(const unsigned char *s, size_t n) {
    if (has(s, n, "/dev/tcp/") || has(s, n, "/dev/udp/")) return 1;
    if ((has_ci(s, n, "nc ") || has_ci(s, n, "ncat ") || has_ci(s, n, "socat ")) && has_ci(s, n, "-e")) return 1;
    if (has_ci(s, n, "mkfifo") && (has(s, n, "| sh") || has(s, n, "| bash") || has(s, n, "| zsh"))) return 1;
    return 0;
}

static int network_tool(const unsigned char *s, size_t n) {
    return word(s, n, "curl") || word(s, n, "wget") || word(s, n, "fetch");
}

static int remote_pipe(const unsigned char *s, size_t n) {
    if (!network_tool(s, n)) return 0;
    if (!(has(s, n, "| sh") || has(s, n, "| bash") || has(s, n, "| zsh") ||
          has(s, n, "| dash") || has(s, n, "| ksh") || has(s, n, "| sudo sh") ||
          has(s, n, "| sudo bash") || has(s, n, "| sudo zsh"))) return 0;
    return 1;
}

int arxguard_scan_bytes(const unsigned char *s, size_t n, struct arxguard_result *r) {
    if (!r) return -1;
    memset(r, 0, sizeof(*r));
    if (!s || !n) return 0;

    const int deep = arxguard_prefilter_bytes(s, n);
    if (deep) {
        for (size_t i = 0; i < n; ++i) {
            unsigned char b = s[i];
            if (b == 0x1b && i + 1 < n && (s[i + 1] == '[' || s[i + 1] == ']' || s[i + 1] == 'P' || s[i + 1] == '_' || s[i + 1] == '^')) {
                add(r, 1, "[CRITICAL] terminal escape/control sequence");
                break;
            }
            if (b == 0 || b == 0x7f || (b < 0x20 && b != '\n' && b != '\r' && b != '\t' && b != 0x1b)) {
                add(r, 2, "[HIGH] unexpected control byte");
                break;
            }
        }
        static const char *u[] = {
            "\xE2\x80\x8B", "\xE2\x80\x8C", "\xE2\x80\x8D", "\xE2\x80\x8E", "\xE2\x80\x8F",
            "\xE2\x80\xAA", "\xE2\x80\xAB", "\xE2\x80\xAC", "\xE2\x80\xAD", "\xE2\x80\xAE",
            "\xE2\x81\xA0", "\xE2\x81\xA6", "\xE2\x81\xA7", "\xE2\x81\xA8", "\xE2\x81\xA9", "\xEF\xBB\xBF"
        };
        for (size_t i = 0; i < sizeof(u) / sizeof(u[0]); ++i)
            if (has(s, n, u[i])) { add(r, 1, "[CRITICAL] invisible/bidi Unicode control"); break; }
    }

    if (destructive(s, n)) add(r, 1, "[CRITICAL] destructive or raw-disk command");
    if (reverse_shell(s, n)) add(r, 1, "[CRITICAL] network-to-shell/reverse-shell pattern");

    if (remote_pipe(s, n)) {
        int privileged = has(s, n, "| sudo sh") || has(s, n, "| sudo bash") || has(s, n, "| sudo zsh");
        int command_shell = has_ci(s, n, "| sh -c") || has_ci(s, n, "| bash -c") || has_ci(s, n, "| zsh -c") || has_ci(s, n, "| dash -c") || has_ci(s, n, "| ksh -c");
        int wget_stream = has_ci(s, n, "-O- | zsh") || has_ci(s, n, "-O- | bash") || has_ci(s, n, "-O- | sh") || has_ci(s, n, "--output-document=- | zsh");
        if (privileged || command_shell || wget_stream) add(r, 1, "[CRITICAL] suspicious remote content piped into shell");
        else add(r, 2, "[MEDIUM] remote content piped to interpreter");
    }

    if ((has_ci(s, n, "base64 -d") || has_ci(s, n, "base64 --decode") || has_ci(s, n, "xxd -r") || has_ci(s, n, "openssl enc -d")) && has(s, n, "|"))
        add(r, 1, "[CRITICAL] decoded payload piped to execution");

    if ((has_ci(s, n, "curl ") || has_ci(s, n, "wget ")) && (flag(s, n, "-k") || flag(s, n, "--insecure") || flag(s, n, "--no-check-certificate")))
        add(r, 2, "[HIGH] transport verification disabled");

    if ((has_ci(s, n, "apt ") || has_ci(s, n, "apt-get ") || has_ci(s, n, "dnf ") || has_ci(s, n, "yum ") || has_ci(s, n, "pacman ")) &&
        (has_ci(s, n, "--allow-unauthenticated") || has_ci(s, n, "--nogpgcheck") || has_ci(s, n, "trusted=yes")))
        add(r, 1, "[CRITICAL] package signature verification disabled");

    if ((has_ci(s, n, "curl ") || has_ci(s, n, "wget ") || has_ci(s, n, "scp ") || has_ci(s, n, "rsync ")) &&
        (has_ci(s, n, ".ssh/") || has_ci(s, n, "id_rsa") || has_ci(s, n, "id_ed25519") || has_ci(s, n, ".aws/") ||
         has_ci(s, n, ".netrc") || has_ci(s, n, ".git-credentials") || has_ci(s, n, ".kube/config") || has_ci(s, n, "github_token")))
        add(r, 1, "[CRITICAL] network command references credential material");

    if ((has_ci(s, n, "authorized_keys") || has_ci(s, n, "/etc/cron") || has_ci(s, n, ".bashrc") || has_ci(s, n, ".zshrc")) &&
        (has(s, n, ">>") || has(s, n, "> ") || has_ci(s, n, "tee")))
        add(r, 2, "[HIGH] persistence or authorization modification");

    if (has_ci(s, n, "chmod 777") || (has_ci(s, n, "eval ") && (has_ci(s, n, "curl") || has_ci(s, n, "wget"))))
        add(r, 2, "[HIGH] unsafe privilege or dynamic execution pattern");

    if (has_ci(s, n, "http://") || has_ci(s, n, "https://") || has_ci(s, n, "www.")) {
        int nonascii = 0;
        for (size_t i = 0; i < n; ++i) if (s[i] >= 0x80) { nonascii = 1; break; }
        if (nonascii) {
            add(r, 2, "[HIGH] non-ASCII network text requires homograph/IDN review");
            if (remote_pipe(s, n)) add(r, 1, "[CRITICAL] homograph/IDN network content piped into shell");
        }
    }

    return r->code;
}

int arxguard_scan_cstr(const char *s, struct arxguard_result *r) {
    return arxguard_scan_bytes((const unsigned char *)s, s ? strlen(s) : 0, r);
}

const char *arxguard_version(void) { return "0.4.0-native"; }
