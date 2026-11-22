# 03: Bash properly

Lab: `sre-lab`. Scripts: [`bash/backup/backup.sh`](../bash/backup/backup.sh) and [`bash/practice/`](../bash/practice/).

---

## 1. Quoting

Wrap every variable in double quotes. Without them, bash splits the value on spaces.

```bash
file="my notes.txt"
touch $file      # makes TWO files: "my" and "notes.txt"
touch "$file"    # makes one file: "my notes.txt"
```

| Quotes | What happens inside | Use for |
|---|---|---|
| `"double"` | `$var` and `$(cmd)` get filled in | anything with a variable. Most of the time |
| `'single'` | nothing changes, everything is literal | awk, sed and grep patterns, literal `$` |

```bash
name="Abtahee"
echo "hi $name"     # hi Abtahee
echo 'hi $name'     # hi $name
```

- `$(command)` puts a command's output into a string: `today="$(date +%F)"`
- Quotes inside `$(...)` are separate from the outer ones, so quote in there too: `"$(basename "$dir")"`
- Quotes don't nest. A second `"` closes the first. `"hello "$x""` leaves `$x` **unquoted**. Write `"hello $x"`
- `ls` shows names with spaces in single quotes, like `'my notes.txt'`. That's only how it displays them. The quotes aren't part of the name (`ls -N` hides them)

## 2. Tests with `[[ ]]`

```bash
if [[ -d "$dir" ]]; then echo "is a directory"; fi
```

| Test | True when |
|---|---|
| `-e "$x"` | x exists, any type |
| `-f "$x"` | x is a regular file |
| `-d "$x"` | x is a directory |
| `-z "$x"` | x is an empty string |
| `-n "$x"` | x is not empty |
| `"$a" == "$b"` | strings match |
| `$a -eq $b`, `-gt`, `-lt`, `-ge`, `-le` | number comparisons |

- `&&`, `||` and `!` work inside: `[[ -f "$a" && -f "$b" ]]`
- `[ ]` (single) is the old version. It's actually a separate program (`/usr/bin/[`), and it breaks on empty unquoted variables. In bash scripts, use `[[ ]]`
- `-n` and `-z` are for strings. `$#` with no arguments is the text `0`, which is **not** empty, so `[[ -n "$#" ]]` is always true. Compare numbers with `-gt` etc.
- `/dev/null` exists but is neither `-f` nor `-d`. Use `-e` to check "exists at all"

## 3. Loops

```bash
for f in /home/malzi/*; do       # * expands to every name in the folder
    du -sh "$f"
done

for i in {1..5}; do echo "$i"; done

while read -r line; do           # one line at a time
    echo "got: $line"
done < somefile.txt              # < feeds the file into the whole loop
```

- `for x in LIST` runs once per item. `for f in /home/malzi` is a list of **one** item, the folder itself
- `*` is a wildcard. Bash replaces it with every matching name **before** the command runs
  - `*` skips hidden files (names starting with `.`). `.[!.]*` matches them without catching `.` and `..`
  - Wildcards **don't expand inside quotes**: `"$dir-*.tar.gz"` looks for a literal `*`. Write `"$dir"-*.tar.gz`
- `read` reads one line and succeeds. It fails when there are no lines left, which ends the loop
- `-r` stops `read` from eating backslashes. Always use it
- `while read` also works with a pipe: `ls | while read -r f; do ...; done`
- Maths: `count=$((count + 1))`
- `du -h` on a folder lists every subfolder. `du -sh` gives one total

## 4. Functions

```bash
greet() {
    local name="$1"      # $1 = the function's first input. local keeps it inside
    echo "hi $name"
    return 0             # exit code 0 to 255, NOT a value
}

greet "Abtahee"          # call it: no brackets
```

- Define it with `name() { ... }`. Call it with just `name` (writing `name()` to call it is a syntax error)
- It has to be defined **above** where you call it
- Defining a function doesn't run it. Nothing happens until it's called
- Inside a function, `$1`, `$2` are the **function's** inputs, not the script's. Pass them in, or use a variable set at the top of the script
- `return` only sets the exit code. To get text back, `echo` it and capture it with `$(...)`:

```bash
double() { echo $(( $1 * 2 )); }
result="$(double 5)"     # 10
```

- `echo 0` does **not** set the exit code. It just prints "0", and `echo` itself succeeds, so `if` always sees success
- `[[ ]]` sets its own exit code, so a function can just be `is_dir() { [[ -d "$1" ]]; }`

| Symbol | Meaning |
|---|---|
| `$1`, `$2` | inputs (to the script, or to a function inside it) |
| `$#` | how many inputs |
| `$@` | all the inputs |

## 5. Exit codes

Every command finishes with a number: **0 means success**, 1 to 255 means failure.

```bash
ls /nope
echo $?        # 2. $? = exit code of the last command
```

- `exit 1` stops the whole script with a failure code
- `exit` with no number uses the last command's code. After an `echo`, that's 0, meaning success, so always give a number
- `A || B` runs B only if A **fails**. `A && B` runs B only if A **succeeds**
- Put the **check** on the left of `||`, not `echo` (echo never fails, so B would never run):

```bash
[[ "$#" -gt 0 ]] || { echo "No argument given" >&2; exit 1; }
```

- `{ ...; }` groups commands. You need the spaces inside the braces and the `;` before `}`
- `>&2` sends output to stderr (stream 2, for errors) instead of stdout (stream 1, for results)
- `A && B || C` gives C if either A or B fails

## 6. Strict mode

First line after the shebang:

```bash
set -euo pipefail
```

| Flag | Effect | Saves you from |
|---|---|---|
| `-e` | stop at the first failed command | `cd /nope` failing, then `rm -rf *` running in the wrong folder |
| `-u` | an unset variable is an error | a typo like `$naem` quietly becoming empty |
| `-o pipefail` | a pipeline fails if any part fails | `false \| echo hi` hiding the failure |

- Without `-u`, `rm -rf "/var/backups/$naem"` becomes `rm -rf "/var/backups/"`
- With `-u`, using `$1` when no argument was given crashes the script, so check `$#` **before** touching `$1`
- If a command is allowed to fail: `grep x file || true`

## 7. Tools from backup.sh

```bash
tar -czf archive.tar.gz somedir    # c = create, z = gzip, f = archive name comes next
date +%F                           # 2026-11-22
date +%F_%H%M%S                    # 2026-11-22_133901 (hours, minutes, seconds)
basename /home/malzi/practice      # practice (last part of a path)
ls -t                              # newest first
head -n 5                          # first 5 lines
tail -n +6                         # from line 6 onwards. tail -n 6 = last 6 lines
wc -l                              # count lines
rm -- "$f"                         # -- means nothing after it is an option
chmod +x script.sh                 # make it runnable (same effect as chmod 755)
ls -ld /var/backups                # details of the folder itself
```

- `tar -czf` order: the archive name **right after** `-f`, then what goes inside
- `tar: Removing leading '/' from member names` is a note, not an error
- With a pile of errors, the **first** one is usually the cause
- New scripts need `chmod +x` before `./script.sh` works. `sudo` doesn't fix a missing execute bit
- `/var/backups` is `drwxr-xr-x root root`, so only root can write there. Run the script with `sudo`
- Variables: no spaces around `=`. `dir = "$1"` runs a command called `dir`

## Mistakes I made building backup.sh

1. Spaces around `=` in an assignment
2. Used `$1` and `$dir` before checking or setting them (crashes under `-u`)
3. Chained checks with `||`, so passing the first check skipped the second
4. `touch` instead of `tar`, which makes an empty file, not an archive
5. Full path in the file name: `/var/backups//home/malzi/practice-...`. Fixed with `basename`
6. tar arguments backwards
7. `exit` with no number exits 0
8. `tail -n +5` kept 4, not 5
9. `*` inside quotes doesn't expand
10. Defined `cleanup` but never called it, then called it as `cleanup()`
