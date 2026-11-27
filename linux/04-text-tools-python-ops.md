# 04: Text tools + Python for ops

Lab: `sre-lab`, in `~/textlab`. Scripts: [`text-tools/`](../text-tools/).

Logs are just text. These tools answer questions like "how many errors?" and "who's hitting us most?".

---

## The nginx log line

```
10.0.0.7 - - [22/Nov/2026:13:39:01 +0000] "GET /login HTTP/1.1" 404 512 "-" "curl/8.0"
```

| Field (awk, cut) | Python index | Value | Meaning |
|---|---|---|---|
| 1 | 0 | `10.0.0.7` | client IP |
| 4 | 3 | `[22/Nov/2026:13:39:01` | date and time |
| 6 | 5 | `"GET` | method (with a quote stuck on) |
| 7 | 6 | `/login` | path |
| 9 | 8 | `404` | status: 200 OK, 301 redirect, 404 not found, 500 server error |
| 10 | 9 | `512` | response size in bytes |

awk and cut count from **1**. Python lists count from **0**.

---

## 1. grep: find lines

```bash
grep "POST" access.log      # matching lines
grep -c "POST" access.log   # count them
grep -v "GET" access.log    # lines that DON'T match
grep -i "post" access.log   # ignore case
grep -E '...' access.log    # extended regex
```

| Regex | Means |
|---|---|
| `.` | any one character. `\.` is a real dot |
| `*` / `+` | the thing **directly before** it, 0+ / 1+ times |
| `[0-9]` | one digit. `[1-9]` excludes 0 |
| `{3}` | the thing before, exactly 3 times (`-E`) |
| `a\|b` | a or b (`-E`), grouped with `( )` |
| `^` / `$` | start / end of the **whole line** |

**Lessons from practice:**
- Anchor to the field using the characters around it: `'^10\.0\.0\.5 '` for an IP, `'1\.1" 500 '` for a status
- Mark where the field **ends** (usually a space), or `10.0.0.5` also matches `10.0.0.50`
- `$` is the end of the line, not the end of a field. `"...5$"` never matches mid-line
- grep matches part of a line. `1[0-9]` matches inside `10.0.0.150` unless you mark the end
- `.+` is "anything". Not `/+.` (repeats the slash), and not `\.+` (repeats a literal dot)
- Use single quotes for patterns
- `.*` between two things allows anything in between: `'/api/.* 404'`

```bash
grep -c '"POST' access.log                       # POSTs
grep -cv '^10\.0\.0\.5 ' access.log              # not from 10.0.0.5
grep -c '\.1" (404|500) ' -E access.log          # 404 or 500
grep -c '^10\.0\.0\.1[0-9] ' access.log          # 10.0.0.10 to .19
grep -c '13:0[0-9]:[0-9][0-9] ' access.log       # first 10 minutes
grep -Ec ' [1-9][0-9]{3} "-"' access.log         # 4-digit sizes
```

## 2. cut: pull out columns

```bash
cut -d ' ' -f 7 access.log          # field 7, split on spaces
cut -d ' ' -f 1,9 access.log        # list of fields: ONE -f, comma separated
cut -d ' ' -f 1-3                   # range. -f -9 = fields 1 to 9, -f 7- = 7 to end
cut -d '"' -f 2 access.log          # split on quotes: GET /login HTTP/1.1
```

- Only one `-f` per cut
- Each cut numbers its fields fresh, from **its own** input and delimiter. `"POST` split on `"` gives field 1 = empty, field 2 = `POST`
- When printing several fields, cut joins them with the delimiter (`13:39:01`)
- Splits on exactly one character, so two spaces in a row make an empty field
- In a pipe, only the first command names the file

```bash
cut -d ' ' -f 6 access.log | cut -d '"' -f 2          # method without the quote
cut -d ' ' -f 4 access.log | cut -d ':' -f 2-         # time only
```

## 3. sort and uniq: count things

```bash
sort / sort -n / sort -r / sort -rn     # text, numbers, reversed, biggest first
sort -u                                 # sort and drop duplicates
uniq                                    # drop repeats (next to each other only)
uniq -c                                 # count repeats
```

`uniq` only merges lines **next to each other**, so always `sort` first.

| Want | Pipeline |
|---|---|
| count per value | `cut ... \| sort \| uniq -c \| sort -rn` |
| top N | add `\| head -n N` |
| bottom N | `sort -n \| head`, or `tail` on the reversed list |
| how many different values | `sort -u \| wc -l` |

Watch out for: forgetting `sort`, a stray `head` cutting results, the wrong field, and including two fields (`-f 1,9` counts pairs).

## 4. awk: the column tool

```bash
awk '{print $1, $9}' access.log                     # comma = space between
awk '$9 == 500 {print $1, $9}' access.log           # filter, then act
awk '$9 == 200 {total += $10} END {print total}'    # running total
awk '{count[$7]++} END {for (k in count) print count[k], k}' access.log | sort -rn
awk -F'"' '{print $2}' access.log                   # split on quotes
```

- Program in **single quotes**, so bash doesn't eat `$1`
- `{ }` runs once per line. `END { }` runs once at the end
- Splits on any whitespace by default
- `$9 == 500` compares the field exactly, with no anchoring needed (easier than grep for columns)
- `print $1 $9` without a comma joins them with no space
- Arrays count by themselves, so no sort is needed before counting. Easy to add filters: `$9 == 404 {count[$7]++}`

## 5. sed: find and replace

```bash
sed 's/cat/dog/'          # first match per line
sed 's/cat/dog/g'         # all matches
sed 's|/home/malzi|~|'    # any character after s is the divider
sed -n '1,3p' file        # only lines 1 to 3 (range = first,last)
sed -n '/POST/p' file     # only matching lines
sed -E 's/^([0-9.]+) .*/IP=\1/'   # capture with ( ), put back with \1
sed -i 's/a/b/' file      # edit the file in place (no undo)
```

- Needs all three dividers: `unterminated 's' command` means the closing one is missing
- Pick a divider that isn't in the text
- `5,10` in sed is a **range**, not a list like cut. `1,2,3p` errors
- `.*` is greedy and grabs as much as it can. Prefer a tight pattern like `[0-9.]+`
- A `>` prompt in bash means an unclosed quote. `Ctrl+C` to escape

---

## 6. Python for ops

### pathlib

```python
from pathlib import Path
p = Path("access.log")
p.exists()      # anything at that path, folders included
p.is_file()     # a regular file
p.is_dir()      # a folder
p.name, p.suffix
for line in p.open(): ...      # one line at a time
Path.home() / "textlab"        # / joins paths (not division)
```

- Each line read from a file ends with `\n`. `print` adds another, so use `.strip()` to avoid blank lines
- `"200\n" != "200"`, so strip (or `split()`) before comparing
- `repr(x)` shows hidden characters

### argparse

```python
import argparse
parser = argparse.ArgumentParser(description="shown in --help")
parser.add_argument("file")                        # positional, required
parser.add_argument("--top", type=int, default=5)  # option with a default
args = parser.parse_args()
args.file, args.top
```

- The attribute name is exactly what's in `add_argument` (it's case-sensitive)
- Missing arguments and bad types get an automatic error and exit 2
- `--help` is free, so write a real description

### logging

```python
import logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logging.info("starting")
logging.error(f"file not found: {p}")
```

- `basicConfig` goes once, near the top. It only sets things up and logs nothing itself
- `level=` is the cut-off: messages below it are hidden. DEBUG < INFO < WARNING < ERROR < CRITICAL
- `logging.ERROR` is the level setting, `logging.error()` is the function
- Goes to **stderr**: `print` is for results, logging is for messages about the run
- Put the file or path in messages so they explain themselves

### subprocess

```python
import subprocess
result = subprocess.run(["wc", "-l", p], capture_output=True, text=True, check=True)
result.stdout, result.stderr, result.returncode
```

- A **list**, one item per argument. `["cut -d ' ' -f 9"]` looks for a program with that whole name
- No bash is involved, so no `' '` quoting is needed: `["cut", "-d", " ", "-f", "9"]`
- Pipes are a bash feature and don't work in the list form. `shell=True` with one string allows them, but risks command injection with user input
- `result` is an object. The text is `result.stdout`
- `check=True` raises an error on a non-zero exit (like `set -e` for that command)
- Path objects can go straight in the list

### Counting

```python
from collections import Counter
c = Counter()
c[key] += 1                       # missing keys start at 0
for item, count in c.most_common(5):
    print(count, item)
```

- `line.split()` (no argument) splits on any whitespace, like awk. `split(" ")` breaks on double spaces
- Count everything in **one pass**: split each line once and update every counter in the same loop
- `sys.exit(1)` (with `import sys`) for scripts, not `exit()`

---

## Debugging on my own

1. Run it and read the **last line** of the traceback (the error), then the line above it (my code and its line number)
2. Wrong output but no crash: `print(type(x))`, `print(repr(x))`
3. `python3 -i script.py args`, then poke at variables, `dir(x)`, `help(x)`
4. Docs: docs.python.org, `man cmd`

| Error | Usually |
|---|---|
| `AttributeError` | `.thing` on the wrong kind of object |
| `NameError` | typo or not set yet |
| `IndexError` | list shorter than the index |
| `FileNotFoundError` | wrong path, or a wrong command name in subprocess |

---

## Side quest: the VM clock was 15 hours behind

```bash
timedatectl                    # clock, time zone, "synchronized: yes/no"
chronyc tracking               # how far off ("System time: N seconds slow")
chronyc sources                # time servers. ^* = synced, ^? = unreachable
sudo chronyc makestep          # jump straight to the right time
sudo hwclock --systohc         # copy system time to the hardware clock
```

- Ubuntu 25.10+ uses **chrony**, not `systemd-timesyncd`
- chrony normally **slews** (adjusts slowly) so the clock never jumps on a live server. `makestep` forces a jump when it's way off
- Wrong clocks mean wrong log timestamps and wrong dated file names
