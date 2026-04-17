#!/usr/bin/env python3
"""Audit quesiti .txt: opzioni duplicate (stesso testo normalizzato) nella stessa domanda."""
from __future__ import annotations

import re
import sys
from pathlib import Path


def extract_itemdomanda_blocks(text: str) -> list[tuple[str, str]]:
    """Ritorna [(question, options_raw), ...] per ogni \\itemdomanda trovato."""
    out: list[tuple[str, str]] = []
    key = r"\itemdomanda{"
    pos = 0
    while True:
        i = text.find(key, pos)
        if i == -1:
            break
        j = i + len(key)
        depth = 1
        q_start = j
        while j < len(text) and depth:
            if text[j] == "{":
                depth += 1
            elif text[j] == "}":
                depth -= 1
            j += 1
        if depth != 0:
            break
        question = text[q_start : j - 1]
        while j < len(text) and text[j] in " \t\n\r":
            j += 1
        if j >= len(text) or text[j] != "{":
            pos = i + len(key)
            continue
        j += 1
        depth = 1
        o_start = j
        while j < len(text) and depth:
            if text[j] == "{":
                depth += 1
            elif text[j] == "}":
                depth -= 1
            j += 1
        options = text[o_start : j - 1]
        out.append((question, options))
        pos = j
    return out


def split_options(options_raw: str) -> list[str]:
    """
    Spezza il blocco opzioni in singole alternative.
    Ogni opzione inizia con \\item (non \\itemdomanda) a profondità 0 di graffe.
    """
    parts: list[str] = []
    depth = 0
    i = 0
    n = len(options_raw)
    current_start: int | None = None

    def is_item_at(k: int) -> bool:
        if not options_raw.startswith(r"\item", k):
            return False
        if options_raw.startswith(r"\itemdomanda", k):
            return False
        return True

    while i < n:
        ch = options_raw[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
        if depth == 0 and is_item_at(i):
            if current_start is not None and i > current_start:
                parts.append(options_raw[current_start:i].strip())
            current_start = i
            i += 5
            continue
        i += 1
    if current_start is not None:
        tail = options_raw[current_start:].strip()
        if tail:
            parts.append(tail)
    cleaned: list[str] = []
    for p in parts:
        p = p.strip()
        if p.startswith(r"\item"):
            p = p[5:].lstrip()
        cleaned.append(p)
    return cleaned


def normalize_option(s: str) -> str:
    s = s.strip()
    s = re.sub(r"\s+", " ", s)
    s = s.replace("{,}", ",")
    return s.casefold()


def audit_file(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8", errors="replace")
    issues: list[str] = []
    blocks = extract_itemdomanda_blocks(text)
    if not blocks:
        if "Risposta Corretta:" in text:
            issues.append("contiene Risposta Corretta ma nessun \\itemdomanda parsabile")
        return issues
    for bi, (_q, opts) in enumerate(blocks):
        choices = split_options(opts)
        if len(choices) < 2:
            issues.append(f"blocco {bi}: meno di 2 opzioni parsate ({len(choices)})")
            continue
        by_norm: dict[str, list[int]] = {}
        for idx, c in enumerate(choices, start=1):
            key = normalize_option(c)
            if len(key) < 2 and key.isalnum():
                pass
            by_norm.setdefault(key, []).append(idx)
        for key, idxs in sorted(by_norm.items(), key=lambda x: x[1][0]):
            if len(idxs) > 1:
                preview = key[:80] + ("…" if len(key) > 80 else "")
                issues.append(f"blocco {bi}: opzioni duplicate indici {idxs} :: {preview!r}")
    return issues


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    files = sorted(root.glob("Q - */**/*.txt"))
    dup_files: list[tuple[Path, list[str]]] = []
    for p in files:
        iss = audit_file(p)
        if iss:
            dup_files.append((p, iss))
    for p, iss in dup_files:
        print(f"\n== {p.relative_to(root)}")
        for line in iss:
            print(f"   {line}")
    print(f"\nTotale file con problemi: {len(dup_files)} / {len(files)}")
    return 0 if not dup_files else 1


if __name__ == "__main__":
    sys.exit(main())
