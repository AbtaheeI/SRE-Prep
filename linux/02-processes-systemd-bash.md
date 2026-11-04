# 02: Processes, systemd, apt and bash

Lab: `sre-lab` (Ubuntu VM), reached with `ssh -p 2222 127.0.0.1` from the Mac.
Check the prompt first: `malzi@sre-lab` is the VM, `malzi@Abtahees-MacBook-Pro` is the Mac.

---

## 1. Processes

A process is a running program. Every process has a PID (process ID) and runs as a user.

```bash
ps aux                 # every process: USER, PID, %CPU, %MEM, STAT, COMMAND
ps aux | grep nginx    # just the ones I care about
pgrep -a nginx         # PIDs + commands, without the grep line itself
top                    # live view. P = sort by CPU, M = sort by memory, q = quit
htop                   # nicer top
nproc                  # how many CPU cores
```

### STAT column

| Letter | Meaning |
|---|---|
| R | running |
| S | sleeping, waiting for something (normal for most processes) |
| D | stuck waiting on disk/IO, can't be interrupted. Lots of these = disk trouble |
| Z | zombie: finished, but its parent never cleaned it up |
| T | stopped (e.g. Ctrl+Z) |

### Load average

`top` shows three numbers: average load over the last 1, 5 and 15 minutes.
Compare against `nproc`. With 2 cores, a load of 2 means fully busy. Above 2 means work is queuing.

### Signals

| Signal | Number | How | Meaning |
|---|---|---|---|
| SIGTERM | 15 | `kill PID` (default) | please stop. Program can clean up, or ignore it |
| SIGKILL | 9 | `kill -9 PID` | stop now. Can't be ignored. Last resort |
| SIGINT | 2 | Ctrl+C | interrupt from the keyboard |
| SIGTSTP | 20 | Ctrl+Z | pause (not kill) |

```bash
kill 1234              # SIGTERM to one PID
pkill yes              # SIGTERM to every process named yes
pkill -u alice         # every process owned by alice
pkill -9 -u alice      # force it
```

Always try SIGTERM first. SIGKILL skips cleanup, which can leave half-written files.

### Background jobs

```bash
yes > /dev/null &      # & runs it in the background, prompt comes straight back
echo $!                # PID of the last background job
jobs                   # list my background jobs
fg                     # bring it to the front
# Ctrl+Z pauses it, bg resumes it in the background
```

Mistake I made: ran `yes` without `&`, and it flooded the terminal. Ctrl+C stops it.

---

## 2. systemd

systemd starts and looks after services (programs that run in the background, like ssh or nginx).

### systemctl

```bash
systemctl status nginx          # running? enabled? recent logs
sudo systemctl start nginx      # start now
sudo systemctl stop nginx
sudo systemctl restart nginx
sudo systemctl enable nginx     # start automatically at boot
sudo systemctl disable nginx
sudo systemctl enable --now X   # enable + start in one go
systemctl is-active nginx       # prints active / inactive / failed
systemctl is-enabled nginx
systemctl --failed              # everything that's failed
```

**start vs enable:** `start` = run it now. `enable` = run it at every boot. They're separate. A service can be running but not enabled (gone after reboot), or enabled but not running.

ssh is reached through `ssh.socket` on this VM: systemd listens on the port and starts `ssh` when someone connects.

### Unit files: where they live

| Folder | Whose | Edit it? |
|---|---|---|
| `/usr/lib/systemd/system/` | installed by packages (apt) | no, an update will overwrite it |
| `/etc/systemd/system/` | mine | yes, my own units go here |

After creating or changing any unit file: `sudo systemctl daemon-reload` (not `sudo daemon-reload`).

### A service

```ini
[Unit]
Description=service to run disk_check

[Service]
Type=oneshot
ExecStart=/usr/local/bin/disk_check.sh
```

- `Type=oneshot`: runs, finishes, exits. Shows `inactive (dead)` afterwards, which is normal.
- `Type=simple`: keeps running (like a web server).
- `ExecStart` = full path to the actual program or script, not the folder it's in.
- Keys and values are case sensitive: `Type=oneshot`, not `type=oneshot` or `Type = Simple`.

### A timer

```ini
[Unit]
Description=run disk_check every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
```

- `disk_check.timer` triggers `disk_check.service` automatically because the names match.
- `OnBootSec` = first run after boot. `OnUnitActiveSec` = how often after that.
- Timers can fire up to 1 min late by default (`AccuracySec`), to batch wake-ups.
- `[Install] WantedBy=` is what `enable` uses. It creates a symlink in `/etc/systemd/system/timers.target.wants/`. Without it, enable fails.
- The service has no `[Install]`, so it shows `static`. That's fine, the timer starts it.

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now disk_check.timer
systemctl list-timers --no-pager      # --no-pager stops the screen redrawing
sudo systemctl start disk_check.service   # test now instead of waiting 5 min
```

**Timer vs enable:** enable = once at boot. Timer = on a schedule, again and again.

### Reading status codes

| In `systemctl status` | Meaning |
|---|---|
| `status=0/SUCCESS` | ran fine |
| `status=1/FAILURE` | my script ran and chose to exit 1 |
| `status=203/EXEC` | systemd couldn't even start the program (wrong path, no x permission) |

### cron (the older way)

```bash
crontab -e     # edit my scheduled jobs
crontab -l     # list them
```

```
*/5 * * * *  /usr/local/bin/disk_check.sh
│   │ │ │ │
│   │ │ │ └ day of week (0-7, Sun = 0 or 7)
│   │ │ └── month
│   │ └──── day of month
│   └────── hour
└────────── minute  (*/5 = every 5 minutes)
```

Timers are preferred now: logs go to the journal, `list-timers` shows next/last run, and failures show in `systemctl status`.

---

## 3. Logs with journalctl

```bash
journalctl -u nginx              # logs for one service
journalctl -u nginx -n 20        # last 20 lines (-n 20, not -n -20)
journalctl -u nginx -f           # follow live, Ctrl+C to stop
journalctl --since "10 min ago"
journalctl -p err                # errors and worse
journalctl -b                    # since this boot
journalctl -t disk_check         # by logger tag
journalctl --no-pager            # print it all, no scrolling
```

- `logger -t TAG "message"` writes to the journal. Find it with `journalctl -t TAG`.
- Anything a service prints with `echo` also ends up in the journal.
- Some apps keep their own log files instead. nginx: `journalctl -u nginx` only showed systemd's "Started" lines. The requests are in `/var/log/nginx/access.log`.
- Logs from very short-lived processes sometimes miss the `-u` label. Search with `-t` or by time.

---

## 4. Packages with apt

```bash
sudo apt update              # refresh the catalogue (list of what's available). Changes nothing installed
sudo apt upgrade             # actually install newer versions
apt list --upgradable        # what would upgrade
sudo apt install nginx
sudo apt install -y nginx    # -y = auto-yes, needed in scripts
sudo apt remove nginx        # delete program, KEEP config in /etc
sudo apt purge nginx         # delete program AND config
sudo apt autoremove          # delete dependencies nothing needs any more
apt search nginx
apt show nginx               # version, Installed-Size, Download-Size, depends
dpkg -L htop                 # every file a package installed
which htop                   # where the command is: /usr/bin/htop
```

- `E: Unable to locate package` on a new server: the catalogue is empty or old. Run `sudo apt update`.
- `sudo apt update && sudo apt install -y nginx`: `&&` runs the second only if the first worked.
- `Download-Size` is the compressed download. `Installed-Size` is space on disk after (nginx: 611 kB vs 1,635 kB).
- Dependencies matter for cleanup: `/etc/nginx` belonged to `nginx-common`, so removing `nginx` alone didn't touch it.
- A kernel upgrade only takes effect after `sudo reboot`. Check with `uname -r`. On real servers reboots are planned.

### Investigating nginx after install

| Question | How | Answer |
|---|---|---|
| Running? Enabled? | `systemctl status nginx` | active, enabled (apt enabled it for me) |
| Runs as? | `ps aux \| grep nginx` | master = root, workers = www-data |
| Config | `ls /etc` | `/etc/nginx` |
| Logs | `ls -l /var/log/nginx` | `access.log`, `error.log` |
| Responding? | `curl localhost` | "Welcome to nginx!" HTML |

- Master is root only to open port 80 (ports under 1024 need root). Workers handle requests as www-data: least privilege.
- `access.log` is `www-data adm 640`. I could read it without sudo because I'm in the `adm` group (the group that can read logs on Ubuntu). Linux checks owner, then group, then others, and uses the first that matches.

### curl

Makes a web request from the terminal and prints the raw response.

```bash
curl localhost        # the page
curl -I localhost     # headers only: HTTP/1.1 200 OK
curl -v localhost     # whole conversation
```

`systemctl status` = the process is alive. `curl` = it's actually answering. A service can be "running" but broken.

### Reading an access log line

```
::1 - - [03/Nov/2026:04:22:24 +0000] "GET / HTTP/1.1" 200 615 "-" "curl/8.18.0"
```
Who (`::1` = localhost), when, what (`GET /`), status (`200` OK), bytes sent, what made the request.
Lots of `500`s = server failing. Lots of `404`s = people asking for pages that don't exist.

---

## 5. Bash scripting

```bash
#!/bin/bash           # first line: run this with bash. #! not #1
```

```bash
chmod u+x script.sh   # needs x to run as ./script.sh
./script.sh           # ./ = in the folder I'm in now
/usr/local/bin/x.sh   # / = absolute path from the root
bash script.sh        # works without x: bash is the program, it just reads the file
```

`/usr/local/bin` is on the PATH, so scripts there run by name from anywhere.
Scripts that run as root: owned by root, `755`. If others can write to it, they can put their own commands in and get root.

### Variables and quotes

```bash
name="my notes.txt"       # no spaces around =
touch "$name"             # one file
touch $name               # two files: my and notes.txt
msg="Hello $name, you have $count messages"   # ONE pair of quotes, variables inside
echo 'Hi $name'           # single quotes: printed literally, no variable
```

**Always `"$var"`.** Spaces split things into separate words unless they're in quotes. Same on the command line: `./greet.sh Bob Smith` gives `$1=Bob`, `$2=Smith`. `./greet.sh "Bob Smith"` gives `$1="Bob Smith"`.

### Catching output

```bash
today=$(date +%F)         # run the command, keep what it printed
size=$(du -sm "$1" | cut -f1)
```

`$(...)` = catch output as a value. To just run a command, write it on its own line, no `$()`.

### Arguments

| | Meaning |
|---|---|
| `$0` | the script's own name |
| `$1`, `$2` | first, second argument |

### if

```bash
if [ -z "$name" ]; then
    echo "Usage: $0 NAME"
    exit 1
fi
```

- Spaces inside the brackets matter: `[ -z "$x" ]`, not `[-z "$x"]`.
- `-z` = is it empty.
- Numbers: `-gt` greater, `-lt` less, `-eq` equal, `-ge`, `-le`. Never `>` inside `[ ]`, it means "write to a file".
- `fi` ends it. `else` is optional.
- Check problems at the top and exit early, then the normal code needs no `else`.

### Exit codes

```bash
ls /nope; echo $?     # 2
```

0 = success. Anything else = failure, and the number says what kind (grep: 1 = no match, 2 = real error).
`exit 1` stops the script right there and hands back 1. systemd reads this: exit 1 shows the service as failed.

### Loops

```bash
for service in ssh cron nginx; do           # list of words, no brackets
    echo "$service: $(systemctl is-active "$service")"
done
```

```bash
count=0
while read percent disk; do                 # one line at a time, split into columns
    count=$((count + 1))                    # $(( )) = arithmetic
done < <(df --output=pcent,target | tail -n +2)
```

- `for` = over words. `while read` = over lines, keeps each line together.
- `cmd | while read ...` runs the loop separately, so variables changed inside are lost after `done`. Feed it from the end with `done < <(cmd)` instead.
- `tail -n +2` = from line 2 on (skip the header).
- `tr -d '%'` = delete a character.
- `cut -f1` = keep column 1 (tab separated by default). `-d ':'` to split on something else.

### Writing files with nano

Ctrl+O, Enter = save. Ctrl+X = exit. If it asks "Save modified buffer?" press Y. Always `cat` the file afterwards to check it saved.

---

## 6. Task: disk_check

Warn when any disk is over 80% full, automatically every 5 minutes.

`/usr/local/bin/disk_check.sh` (root:root, 755):

```bash
#!/bin/bash

count=0
while read percent disk; do
    if [ $(echo "$percent" | tr -d "%") -gt 80 ]; then
        msg="WARNING: $disk is $percent full"
        echo "$msg"
        logger -t disk_check "$msg"
        count=$((count + 1))
    fi
done < <(df --output=pcent,target | tail -n +2)

if [ "$count" -eq 0 ]; then
    goodmsg="OK: all disks under 80%"
    echo "$goodmsg"
    logger -t disk_check "$goodmsg"
else
    exit 1
fi
```

Plus `disk_check.service` and `disk_check.timer` above.

Decisions:
- Count warnings and exit at the end, not inside the loop. Exiting inside the loop stops at the first full disk and hides the rest.
- Exit 1 on warnings, so systemd marks the service failed and `systemctl --failed` / monitoring catch it.
- Tested the warning path by dropping the threshold to 10. At 80 it never runs, so a broken warning line would only show up when a real disk filled.

Proof it works:
```bash
systemctl list-timers --no-pager | grep disk_check
systemctl status disk_check.service --no-pager
journalctl -t disk_check -n 5
```

---

## 7. Problems I hit

| Problem | Cause | Fix |
|---|---|---|
| `Unknown key 'type'` | keys are case sensitive | `Type=oneshot` |
| `systemctl start /etc/...` treated as a mount | systemctl wants the unit name | `systemctl start hello.service` |
| `/etc/systemd` doesn't exist | I was editing on the Mac | check the prompt |
| list-timers screen kept redrawing | pager | `--no-pager` |
| Edit to a unit file ignored | systemd caches unit files | `sudo systemctl daemon-reload` |
| `status=203/EXEC` | `ExecStart=/usr/local/bin` (the folder) | full path to the script |
| `./usr/local/bin/x.sh: No such file` | `./` is relative to where I am | `/usr/local/bin/x.sh` |
| `[: too many arguments` | `$(du -sm x)` gives "20 /var/log", two words | `\| cut -f1` |
| Script looked frozen | `logger -t tag` with no message waits for input | `logger -t tag "message"` |
| Two files `my` and `report.txt` | unquoted variable | `"$file"` |
| Edits "didn't work" | nano didn't save | Ctrl+O, Enter. Check with `cat` |
| Log timestamps hours behind | Mac slept, VM clock froze | `sudo chronyc makestep`, check `timedatectl` says synchronized: yes |

Clock: `chronyc sources` lists time servers. `^*` = locked on (good). All `^?` = can't reach any, so check the network with `ping -c 3 1.1.1.1`. Shut the VM down with `sudo poweroff` when done, or run `sudo chronyc makestep` after the Mac wakes.

---

## 8. Copying files between machines: scp

Copy files over SSH. Same login as ssh.

```bash
# run on the Mac
scp -P 2222 malzi@127.0.0.1:/path/on/vm/file.txt .        # VM -> Mac (. = here)
scp -P 2222 -r malzi@127.0.0.1:~/practice bash/            # whole folder
scp -P 2222 notes.md malzi@127.0.0.1:~/                    # Mac -> VM
```

- `-P` capital for the port (ssh uses lowercase `-p`).
- `-r` = a whole folder.
- `machine:path`. The `:` separates which machine from where on it.
- The file has to be readable by the user you log in as.
