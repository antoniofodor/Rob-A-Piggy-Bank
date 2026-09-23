#!/usr/bin/env python3
"""Refuse a Config.luau that reads a field before the file defines it.

WHY THIS EXISTS. `Config` is required by every service and every client, so a
throw while it LOADS takes the whole game down: no plots, no services, no HUD,
no "Ready" in the log. CLAUDE.md records ELEVEN of these, every one the same
shape -- a top-level statement such as

    Config.LAWN_LIFT = Config.PLOT_SIZE.Y      -- PLOT_SIZE defined 900 lines later

written where the thing it reads has not been assigned yet, so the read is
`nil.Y` and Luau throws during module load with a message naming a line that
looks fine. Nothing in the pipeline catches it: `rojo build` packages Luau and
never runs it, and the file is only executed when a server actually starts.

WHAT IT CHECKS. The file is tokenised (strings and comments skipped, CRLF or LF)
and walked statement by statement at load-time scope:

  * Every `function ... end` body is SKIPPED BY CONSTRUCTION -- a body cannot
    run during module load, so a read inside one is fine however early it sits.
    Top-level `for`/`do`/`if`/`while` bodies DO run at load and are walked.
  * Type annotations (`local x: T`, `expr :: T`, `typeof(...)` in a type) are
    skipped: a type is never evaluated.
  * `Config.NAME = ...` DEFINES `NAME` at the END of its statement, because the
    right-hand side is evaluated first -- `Config.X = Config.X or {}` reads X
    before defining it. `function Config.NAME(...)` defines it at once.
  * Every other `Config.NAME` at load-time scope is a READ, and a read of a
    field the file has not defined yet is reported. A read that is then
    INDEXED or CALLED (`Config.X.Y`, `Config.f()`) throws at load and is an
    ERROR; a bare read (`Config.X or 3`) is nil in silence and is a WARNING.

  * Secondly, every top-level `local NAME` is collected and any reference to
    NAME that appears textually BEFORE its declaration -- inside a function
    body or not -- is reported: Luau scoping makes that a nil GLOBAL, which is
    the `glowPart` / `LOCK_TIERS` / `KENNEL_X` family, silent until called.

EXIT CODE. 1 if any error was reported, 0 otherwise (warnings do not fail).

USAGE.
    python tools/check_config_forward_refs.py                 # the repo's Config
    python tools/check_config_forward_refs.py path/to/file    # any Luau file

On this machine `python3` is the Microsoft Store stub; run it with
    /c/Users/anton/AppData/Local/Programs/Python/Python310/python.exe
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT = ROOT / "src" / "ReplicatedStorage" / "Shared" / "Config.luau"
TABLE = "Config"

KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true",
    "until", "while", "continue",
}
BLOCK_OPENERS = {"function", "do", "if", "while", "for", "repeat"}

# Longest first so `...` beats `..` beats `.`, `//=` beats `//` beats `/`.
PUNCT = sorted(
    [
        "...", "..=", "//=", "..", "==", "~=", "<=", ">=", "::", "->", "//",
        "+=", "-=", "*=", "/=", "%=", "^=", "+", "-", "*", "/", "%", "^", "#",
        "=", "<", ">", "(", ")", "{", "}", "[", "]", ";", ":", ",", ".", "?",
        "|", "&",
    ],
    key=len,
    reverse=True,
)


@dataclass
class Tok:
    kind: str  # "name" | "kw" | "num" | "str" | "op"
    text: str
    line: int
    first_on_line: bool


def tokenize(source: str) -> list[Tok]:
    toks: list[Tok] = []
    i, n, line = 0, len(source), 1
    line_had_token = False

    def push(kind: str, text: str, at_line: int) -> None:
        nonlocal line_had_token
        toks.append(Tok(kind, text, at_line, not line_had_token))
        line_had_token = True

    def long_bracket(pos: int) -> int | None:
        """If source[pos:] opens a long bracket `[=*[`, return the level."""
        if source[pos] != "[":
            return None
        j = pos + 1
        while j < n and source[j] == "=":
            j += 1
        return j - pos - 1 if j < n and source[j] == "[" else None

    def skip_long(pos: int, level: int) -> int:
        close = "]" + "=" * level + "]"
        end = source.find(close, pos)
        return n if end < 0 else end + len(close)

    while i < n:
        c = source[i]
        if c == "\n":
            line += 1
            line_had_token = False
            i += 1
            continue
        if c in " \t\r\f\v":
            i += 1
            continue
        if source.startswith("--", i):
            level = long_bracket(i + 2)
            if level is not None:
                end = skip_long(i + 3 + level, level)
            else:
                end = source.find("\n", i)
                end = n if end < 0 else end
            line += source.count("\n", i, end)
            i = end
            continue
        if c in "\"'":
            j = i + 1
            while j < n and source[j] != c:
                if source[j] == "\\":
                    j += 1
                elif source[j] == "\n":
                    break
                j += 1
            push("str", source[i : j + 1], line)
            line += source.count("\n", i, j + 1)
            i = j + 1
            continue
        if c == "`":  # Luau interpolated string; braces inside are expressions
            j = i + 1
            while j < n and source[j] != "`":
                if source[j] == "\\":
                    j += 1
                j += 1
            push("str", source[i : j + 1], line)
            line += source.count("\n", i, j + 1)
            i = j + 1
            continue
        level = long_bracket(i)
        if level is not None:
            end = skip_long(i + 2 + level, level)
            push("str", source[i:end], line)
            line += source.count("\n", i, end)
            i = end
            continue
        if c.isdigit() or (c == "." and i + 1 < n and source[i + 1].isdigit()):
            m = re.match(r"0[xX][0-9a-fA-F_]+|0[bB][01_]+|[0-9_]*\.?[0-9_]+(?:[eE][+-]?[0-9_]+)?", source[i:])
            text = m.group(0) if m else c
            push("num", text, line)
            i += len(text)
            continue
        if c.isalpha() or c == "_":
            m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", source[i:])
            text = m.group(0)
            push("kw" if text in KEYWORDS else "name", text, line)
            i += len(text)
            continue
        for p in PUNCT:
            if source.startswith(p, i):
                push("op", p, line)
                i += len(p)
                break
        else:
            push("op", c, line)
            i += 1
    return toks


EXPR_PREV_OPS = {"=", "(", ",", "{", "[", "+", "-", "*", "/", "%", "^", "..", "==", "~=", "<", ">", "<=", ">=", "//", "->", ":"}
EXPR_PREV_KWS = {"return", "and", "or", "not", "in"}


def opens_block(toks: list[Tok], i: int) -> bool:
    """True if the keyword at i opens a block that a later `end`/`until` closes.
    Two keywords look like openers and are not: the `do` of a `for ... do` /
    `while ... do` header (the loop keyword already counted), and a Luau
    IF-EXPRESSION (`x = if a then b else c`), which has no `end` at all."""
    t = toks[i]
    if t.kind != "kw" or t.text not in BLOCK_OPENERS:
        return False
    if t.text == "do":
        # walk back to the start of this line's statement: a `for`/`while`
        # header owns its `do`.
        j = i - 1
        depth = 0
        while j >= 0:
            u = toks[j]
            if u.kind == "op" and u.text in ")}]":
                depth += 1
            elif u.kind == "op" and u.text in "({[":
                depth -= 1
            elif depth == 0 and u.kind == "kw":
                if u.text in ("for", "while"):
                    return False
                if u.text in ("do", "then", "else", "end", "until", "repeat", "return", "local", "function"):
                    return True
            j -= 1
        return True
    if t.text == "if":
        prev = toks[i - 1] if i else None
        if prev is None:
            return True
        if prev.kind == "op" and prev.text in EXPR_PREV_OPS:
            return False
        if prev.kind == "kw" and prev.text in EXPR_PREV_KWS:
            return False
        return True
    return True


@dataclass
class Finding:
    level: str  # "ERROR" | "WARN"
    line: int
    message: str


class Scanner:
    def __init__(self, toks: list[Tok]) -> None:
        self.toks = toks
        self.defined: set[str] = set()
        self.pending: set[str] = set()  # defined once the current statement ends
        self.findings: list[Finding] = []
        self.everywhere_defined: set[str] = set()
        self.everywhere_read: dict[str, int] = {}

    # -- helpers --------------------------------------------------------------
    def at(self, i: int) -> Tok | None:
        return self.toks[i] if 0 <= i < len(self.toks) else None

    def is_op(self, i: int, text: str) -> bool:
        t = self.at(i)
        return t is not None and t.kind == "op" and t.text == text

    def is_kw(self, i: int, text: str) -> bool:
        t = self.at(i)
        return t is not None and t.kind == "kw" and t.text == text

    # -- types: never evaluated, so skip them entirely -------------------------
    def skip_type(self, i: int) -> int:
        """Return the index just past the type expression starting at i."""
        i = self.skip_type_atom(i)
        while True:
            while self.is_op(i, "?"):
                i += 1
            if self.is_op(i, "|") or self.is_op(i, "&") or self.is_op(i, "->"):
                i = self.skip_type_atom(i + 1)
                continue
            return i

    def skip_type_atom(self, i: int) -> int:
        t = self.at(i)
        if t is None:
            return i
        if t.kind == "op" and t.text in "({<":
            return self.skip_balanced(i)
        if t.kind == "str":
            return i + 1
        if t.kind == "name" and t.text == "typeof" and self.is_op(i + 1, "("):
            return self.skip_balanced(i + 1)
        if t.kind == "name" or (t.kind == "kw" and t.text in ("nil", "true", "false")):
            i += 1
            while self.is_op(i, ".") and (n := self.at(i + 1)) and n.kind == "name":
                i += 2
            if self.is_op(i, "<"):
                i = self.skip_balanced(i)
            return i
        return i

    def skip_balanced(self, i: int) -> int:
        """i is on an opening bracket; return the index past its match."""
        pairs = {"(": ")", "{": "}", "[": "]", "<": ">"}
        stack = [pairs[self.toks[i].text]]
        i += 1
        while i < len(self.toks) and stack:
            t = self.toks[i]
            if t.kind == "op":
                if t.text in pairs:
                    stack.append(pairs[t.text])
                elif t.text == stack[-1]:
                    stack.pop()
            i += 1
        return i

    # -- statements -----------------------------------------------------------
    def skip_block(self, i: int) -> int:
        """i is on a block-opening keyword; return the index past its `end`
        (or past `until <expr>` for repeat). Nested blocks are skipped too."""
        opener = self.toks[i].text
        depth = 1
        i += 1
        while i < len(self.toks) and depth:
            t = self.toks[i]
            if t.kind == "kw":
                if opens_block(self.toks, i):
                    depth += 1
                elif t.text == "end":
                    depth -= 1
                elif t.text == "until":
                    depth -= 1
            i += 1
        if opener == "repeat":
            # `until <expr>`: run to the end of the line's expression; the
            # condition is rare enough at top level that a line is enough.
            line = self.toks[i - 1].line
            while i < len(self.toks) and self.toks[i].line == line:
                i += 1
        return i

    def commit(self) -> None:
        self.defined |= self.pending
        self.pending.clear()

    def note_read(self, i: int, name: str, in_load_scope: bool) -> None:
        self.everywhere_read.setdefault(name, self.toks[i].line)
        if not in_load_scope:
            return
        if name in self.defined:
            return
        indexed = self.is_op(i + 1, ".") or self.is_op(i + 1, "[") or self.is_op(i + 1, "(") or self.is_op(i + 1, ":")
        tok = self.toks[i]
        if indexed:
            self.findings.append(Finding("ERROR", tok.line, f"{TABLE}.{name} is indexed or called before {TABLE}.{name} is defined (throws during module load)"))
        elif name in self.pending:
            self.findings.append(Finding("WARN", tok.line, f"{TABLE}.{name} is read on the right-hand side of its own definition (reads nil)"))
        else:
            self.findings.append(Finding("WARN", tok.line, f"{TABLE}.{name} is read before {TABLE}.{name} is defined (reads nil)"))

    def scan_field_uses(self, lo: int, hi: int, in_load_scope: bool) -> None:
        """Walk toks[lo:hi] at load-time scope: skip function bodies and types,
        record definitions and reads of Config fields."""
        i = lo
        while i < hi:
            t = self.toks[i]
            if t.kind == "kw" and t.text == "function":
                # `function Config.NAME(` defines NAME immediately; the body is
                # skipped, but its Config reads are still noted for the
                # never-defined report.
                if self.at(i + 1) and self.at(i + 1).text == TABLE and self.is_op(i + 2, ".") and self.at(i + 3) and self.at(i + 3).kind == "name" and self.is_op(i + 4, "("):
                    name = self.at(i + 3).text
                    self.defined.add(name)
                    self.everywhere_defined.add(name)
                end = self.skip_block(i)
                self.scan_field_uses(i + 1, end, in_load_scope=False)
                i = end
                continue
            if t.kind == "op" and t.text == "::":
                i = self.skip_type(i + 1)
                continue
            if t.kind == "kw" and t.text == "local" and in_load_scope:
                # `local a: T, b: U = ...` -- skip each annotation.
                i += 1
                while True:
                    if self.at(i) and self.at(i).kind == "name":
                        i += 1
                    if self.is_op(i, ":"):
                        i = self.skip_type(i + 1)
                    if self.is_op(i, ","):
                        i += 1
                        continue
                    break
                continue
            if t.kind == "name" and t.text == TABLE and self.is_op(i + 1, ".") and self.at(i + 2) and self.at(i + 2).kind == "name":
                name = self.at(i + 2).text
                prev = self.at(i - 1)
                is_field_of_something = prev is not None and prev.kind == "op" and prev.text in (".", ":")
                if not is_field_of_something:
                    if self.is_op(i + 3, "="):
                        if in_load_scope:
                            self.pending.add(name)
                        self.everywhere_defined.add(name)
                        i += 4
                        continue
                    self.note_read(i + 2, name, in_load_scope)
                i += 3
                continue
            i += 1

    def run(self) -> None:
        toks = self.toks
        i = 0
        n = len(toks)
        while i < n:
            t = toks[i]
            # A new top-level statement: commit whatever the last one defined.
            self.commit()
            if t.kind == "kw" and t.text in ("do", "if", "while", "for", "repeat"):
                # Runs at load. Walk the whole block as load scope; definitions
                # inside it commit at the block's end, which is conservative in
                # the right direction (a read after them inside the block is
                # still flagged only if it is genuinely earlier).
                end = self.skip_block(i)
                self.scan_field_uses(i, end, in_load_scope=True)
                i = end
                continue
            if t.kind == "kw" and t.text == "function":
                end = self.skip_block(i)
                self.scan_field_uses(i, end, in_load_scope=True)
                i = end
                continue
            # Everything else: the statement runs until the next token that
            # starts a statement -- a keyword statement-starter, or the first
            # token on a line at bracket depth 0.
            j = i + 1
            depth = 0
            while j < n:
                u = toks[j]
                if u.kind == "op":
                    if u.text in "({[":
                        depth += 1
                    elif u.text in ")}]":
                        depth -= 1
                    elif u.text == "::" and depth == 0:
                        # A cast after the statement's own expression: keep it
                        # in this statement (it is skipped as a type anyway).
                        pass
                starts_statement = depth == 0 and u.first_on_line and (
                    (u.kind == "kw" and u.text in ("local", "function", "return", "do", "if", "while", "for", "repeat"))
                    or (u.kind == "name" and not self.is_op(j - 1, "::"))
                )
                if starts_statement:
                    break
                if u.kind == "kw" and u.text == "function":
                    j = self.skip_block(j)
                    continue
                j += 1
            self.scan_field_uses(i, j, in_load_scope=True)
            i = j
        self.commit()


def local_forward_refs(toks: list[Tok]) -> list[Finding]:
    """Top-level `local NAME` declared AFTER a textual reference to NAME."""
    findings: list[Finding] = []
    # First pass: top-level locals and where each is declared.
    declared: dict[str, int] = {}
    depth = 0
    i = 0
    while i < len(toks):
        t = toks[i]
        if t.kind == "kw":
            if opens_block(toks, i):
                depth += 1
            elif t.text == "end" or t.text == "until":
                depth -= 1
            elif t.text == "local" and depth == 0:
                j = i + 1
                if toks[j].kind == "kw" and toks[j].text == "function":
                    j += 1
                while j < len(toks) and toks[j].kind == "name":
                    declared.setdefault(toks[j].text, i)
                    j += 1
                    if j < len(toks) and toks[j].kind == "op" and toks[j].text == ":":
                        # skip the annotation coarsely: to the next `,` or `=`
                        # at bracket depth 0 on this statement's line
                        line = toks[j].line
                        j += 1
                        while j < len(toks) and toks[j].line == line and not (toks[j].kind == "op" and toks[j].text in (",", "=")):
                            j += 1
                    if j < len(toks) and toks[j].kind == "op" and toks[j].text == ",":
                        j += 1
                    else:
                        break
        i += 1
    # Second pass: any reference to a declared name before its declaration,
    # ignoring field accesses (`x.NAME`), method calls, and table keys.
    # Shadowing: a parameter or inner `local` of the same name hides the
    # top-level one for its function, so track names bound inside functions.
    shadow_stack: list[set[str]] = []
    for i, t in enumerate(toks):
        if t.kind == "kw" and t.text == "function":
            # collect params up to the closing `)`
            params: set[str] = set()
            j = i + 1
            while j < len(toks) and not (toks[j].kind == "op" and toks[j].text == "("):
                j += 1
            k = j + 1
            while k < len(toks) and not (toks[k].kind == "op" and toks[k].text == ")"):
                if toks[k].kind == "name" and (k == j + 1 or (toks[k - 1].kind == "op" and toks[k - 1].text == ",")):
                    params.add(toks[k].text)
                k += 1
            shadow_stack.append(params)
        elif t.kind == "kw" and t.text in ("do", "if", "while", "for", "repeat") and opens_block(toks, i):
            names: set[str] = set()
            if t.text == "for":
                j = i + 1
                while j < len(toks) and not (toks[j].kind == "kw" and toks[j].text in ("in", "=")) and not (toks[j].kind == "op" and toks[j].text == "="):
                    if toks[j].kind == "name":
                        names.add(toks[j].text)
                    j += 1
            shadow_stack.append(names)
        elif t.kind == "kw" and t.text in ("end", "until"):
            if shadow_stack:
                shadow_stack.pop()
        elif t.kind == "kw" and t.text == "local" and shadow_stack:
            j = i + 1
            if toks[j].kind == "kw" and toks[j].text == "function":
                j += 1
            while j < len(toks) and toks[j].kind == "name":
                shadow_stack[-1].add(toks[j].text)
                j += 1
                if j < len(toks) and toks[j].kind == "op" and toks[j].text == ",":
                    j += 1
                else:
                    break
        if t.kind != "name" or t.text not in declared:
            continue
        decl_at = declared[t.text]
        if i >= decl_at:
            continue
        prev = toks[i - 1] if i else None
        nxt = toks[i + 1] if i + 1 < len(toks) else None
        if prev and prev.kind == "op" and prev.text in (".", ":"):
            continue  # a field, not this local
        if nxt and nxt.kind == "op" and nxt.text == "=" and prev and prev.kind == "op" and prev.text in ("{", ",", ";"):
            continue  # a table key
        if nxt and nxt.kind == "op" and nxt.text == ":" and prev and prev.kind == "op" and prev.text in ("(", ","):
            continue  # a typed parameter of the same name
        if any(t.text in s for s in shadow_stack):
            continue
        findings.append(Finding("ERROR", t.line, f"`{t.text}` is referenced here but `local {t.text}` is declared at line {toks[decl_at].line} (reads a nil global)"))
    return findings


def main(argv: list[str]) -> int:
    path = Path(argv[1]) if len(argv) > 1 else DEFAULT
    source = path.read_bytes().decode("utf-8", errors="replace").replace("\r\n", "\n").replace("\r", "\n")
    toks = tokenize(source)
    scanner = Scanner(toks)
    scanner.run()
    findings = scanner.findings + local_forward_refs(toks)
    findings.sort(key=lambda f: (f.line, f.level))

    print(f"{path}: {len(toks)} tokens, {len(scanner.defined)} {TABLE} fields defined at load scope")
    for f in findings:
        print(f"  {f.level} line {f.line}: {f.message}")
    never = sorted(name for name in scanner.everywhere_read if name not in scanner.everywhere_defined)
    if never:
        print(f"  INFO {len(never)} {TABLE} field(s) are read somewhere in this file and never assigned in it:")
        for name in never:
            print(f"       {TABLE}.{name}  (first read at line {scanner.everywhere_read[name]})")
    errors = sum(1 for f in findings if f.level == "ERROR")
    warns = len(findings) - errors
    if errors:
        print(f"FAIL: {errors} forward reference(s) would throw or read nil during module load, {warns} warning(s)")
        return 1
    print(f"OK: no forward references at load scope ({warns} warning(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
