# backup.sh

Backs up a directory to `/var/backups` as a dated `.tar.gz`, and keeps only the 5 newest backups for that directory.

## Usage

```bash
sudo ./backup.sh /home/malzi/practice
```

Needs `sudo` because `/var/backups` is owned by root.

Creates a file like `/var/backups/practice-2026-11-22_133901.tar.gz`.

## What it does

1. Stops with exit code 1 if no argument is given
2. Stops with exit code 1 if the argument isn't a directory
3. Archives the directory with `tar -czf`, named `<dirname>-<date>_<time>.tar.gz`
4. Lists that directory's backups newest first and deletes everything after the 5th

Runs in strict mode (`set -euo pipefail`), so any failed command stops the script with a non-zero exit code.

## Tested

```bash
for i in {1..7}; do sudo ./backup.sh /home/malzi/practice; sleep 1; done
ls /var/backups/practice-*.tar.gz | wc -l     # 5

./backup.sh;       echo $?    # No argument given, 1
./backup.sh /nope; echo $?    # argument is not a directory, 1
```
