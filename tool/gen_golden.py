"""Regenerate test/golden/*.json from the Python engine (source of truth).

Run from anywhere:  python pc-flutter/tool/gen_golden.py
It imports parser.py and scanner.py from the project root (the parent of
pc-flutter/) and writes the golden files next to the Dart tests.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.abspath(os.path.join(HERE, "..", "test", "golden"))
sys.path.insert(0, PROJECT_ROOT)

import parser as P  # noqa: E402
import scanner as S  # noqa: E402

UUID = "11111111-2222-3333-4444-555555555555"
DOMAIN = "fast-production-b6e1.up.railway.app"
SAMPLE = (f"vless://{UUID}@{DOMAIN}:443?encryption=none&security=tls&sni={DOMAIN}"
          f"&fp=chrome&alpn=http%2F1.1&type=ws&host={DOMAIN}&path=%2Fws%2F{UUID}#My%20Railway%20Config")
LINK_A = (f"vless://{UUID}@fast-a.up.railway.app:443?encryption=none&security=tls"
          f"&sni=fast-a.up.railway.app&type=ws&host=fast-a.up.railway.app&path=%2Fws#My%20Railway%20Config")
LINK_B = (f"vless://{UUID}@fast-b.up.railway.app:443?security=tls&sni=fast-b.up.railway.app"
          f"&type=ws&path=%2Fother#%DA%A9%D8%A7%D9%86%D9%81%DB%8C%DA%AF%20%D9%85%D9%86")
BAD = "vless://not-a-valid-link"

PARSE_INPUTS = [
    SAMPLE,
    f"vless://{UUID}@example.com",
    "vless://no-at-sign",
    "https://example.com",
    "",
    f"  vless://{UUID}@example.com:8443  ",
    f"vless://{UUID}@h.example:443#My+Name",
    f"vless://{UUID}@h.example:443#bad%ZZ",
    f"vless://{UUID}@h.example:443#abc%4",
    f"vless://{UUID}@h.example:443#%DA%A9%D8%A7%D9%86",
    f"vless://{UUID}@h.example:99999999999",
    f"vless://{UUID}@h.example:2147483647",
    f"vless://{UUID}@h.example:2147483648",
    f"vless://{UUID}@h.example:-1",
    f"vless://{UUID}@h.example:+8443",
    f"vless://{UUID}@h.example:443x",
    f"vless://{UUID}@h.example:",
    f"vless://{UUID}@h.example:\u0664\u0664\u0663",
    f"vless://{UUID}@h.example#name?x=1",
    f"vless://{UUID}@h.example?sni=s.example&host=other.example",
    f"vless://{UUID}@h.example?host=other.example",
    f"vless://{UUID}@h.example?PATH=%2Fabc&SNI=s2.example&Security=none&TYPE=grpc",
    f"vless://{UUID}@h.example?path=ws&sni=",
    f"vless://{UUID}@h.example?path=a+b%20c",
    f"vless://{UUID}@h.example?noequals&x=1=2&path=%2Fp",
    f"vless://{UUID}@h.example?path=%E4%B8%AD%FF",
    f"vless://{UUID}@h.example#%E4%B8%AD%E6%96%87",
    f"vless://{UUID}@h.example",
    f"vless://{UUID}@[::1]:443",
    f"vless://{UUID}@h.example:443#",
    LINK_B,
]

SPLIT_INPUTS = [
    "",
    "   \n  ",
    LINK_A + "\n" + LINK_B + "\n",
    LINK_A + LINK_B,
    LINK_A + "\r\n" + LINK_B,
    LINK_A + "\u2028" + LINK_B,
    LINK_A + "\x0b" + LINK_B,
    "text before " + LINK_A + "   \t trailing\nnext line",
    "vless://\nvless://" + UUID + "@h.example",
    "no scheme here",
]

PF_INPUTS = [BAD + "\n" + LINK_A + "\n" + LINK_B, LINK_A + LINK_B, BAD, ""]


def cfg_dict(cfg):
    if cfg is None:
        return None
    return {"uuid": cfg.uuid, "address": cfg.address, "port": cfg.port,
            "domain": cfg.domain, "path": cfg.path, "security": cfg.security,
            "type": cfg.type, "name": cfg.name}


def main():
    parse_cases = [{"input": s, "expected": cfg_dict(P.parse(s))} for s in PARSE_INPUTS]
    split_cases = [{"input": s, "expected": P.split_candidates(s)} for s in SPLIT_INPUTS]
    pf_cases = []
    for s in PF_INPUTS:
        cfg, found = P.parse_first(s)
        pf_cases.append({"input": s, "found": found,
                         "expected": None if cfg is None else
                         {"domain": cfg.domain, "name": cfg.name, "address": cfg.address}})

    base_a = P.parse(LINK_A)
    base_b = P.parse(LINK_B)
    build_cases = []
    for base, link in ((base_a, LINK_A), (base_b, LINK_B), (P.parse(SAMPLE), SAMPLE)):
        for ip in ["69.46.46.10", "10.0.0.1"]:
            build_cases.append({"base_link": link, "ip": ip,
                                "expected": P.build_config_link(base, ip)})
    fields = {"uuid": UUID, "address": "h", "port": 8443, "domain": "d.example",
              "path": "ws path/\u00e9", "security": "tls", "type": "ws",
              "name": "N ame/\u00e9+!'()*"}
    build_cases.append({"base_fields": fields, "ip": "1.2.3.4",
                        "expected": P.build_config_link(P.VlessConfig(**fields), "1.2.3.4")})

    binary = {
        "vless_header": [{"uuid": UUID, "hex": S.build_vless_header(UUID).hex()}],
        "http_payload_hex": S.build_http_payload().hex(),
        "ws_frame": [
            {"data_hex": bytes(range(40)).hex(), "hex": S.build_ws_frame(bytes(range(40))).hex()},
            {"data_hex": bytes(range(256)).hex(), "hex": S.build_ws_frame(bytes(range(256))).hex()},
            {"data_hex": "", "hex": S.build_ws_frame(b"").hex()},
        ],
        "ws_upgrade": [
            {"domain": DOMAIN, "path": "/ws", "hex": S.build_ws_upgrade_request(DOMAIN, "/ws").hex()},
            {"domain": DOMAIN, "path": "ws", "hex": S.build_ws_upgrade_request(DOMAIN, "ws").hex()},
        ],
        "full_data_hex": S.build_full_vless_data(UUID).hex(),
    }

    os.makedirs(OUT, exist_ok=True)
    files = [("parse.json", parse_cases), ("split.json", split_cases),
             ("parse_first.json", pf_cases), ("build.json", build_cases),
             ("binary.json", binary)]
    for name, obj in files:
        with open(os.path.join(OUT, name), "w", encoding="utf-8", newline="\n") as f:
            json.dump(obj, f, ensure_ascii=False, indent=1)
            f.write("\n")
    print(f"wrote {len(files)} golden files to {OUT}")


if __name__ == "__main__":
    main()
