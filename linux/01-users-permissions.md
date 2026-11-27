# 01: Linux users and permissions

Lab: `sre-lab` (Ubuntu VM), reached with `ssh -p 2222 127.0.0.1` from the Mac.

Always check the prompt before running anything:
- `malzi@Abtahees-MacBook-Pro ~ %` is the Mac
- `malzi@sre-lab:~$` is the VM

---

## 1. Finding your way around

### The layout

| Path | What lives there |
|---|---|
| `/` | root of the whole tree |
| `/home/malzi` | my home folder (`~`) |
| `/root` | root user's home |
| `/etc` | config files. Broken config is usually fixed here |
| `/var/log` | logs. First place to look when something breaks |
| `/tmp` | temp files, wiped on reboot |
| `/usr`, `/bin` | installed programs and basic commands |
| `/proc` | live info about running processes (not real files) |
| `/dev` | devices |
| `/srv` | data for services, e.g. `/srv/app` |

### Moving around

```bash
pwd          # where am I
ls -la       # everything here, including hidden files, with details
cd /etc      # absolute path, works from anywhere
cd ..        # up one level
cd           # home (same as cd ~)
cd -         # back to the last folder I was in (NOT home)
```

### Reading files and logs

```bash
cat file                      # whole file
less file                     # scroll, q to quit
head -n 5 file                # first 5 lines
tail -n 5 file                # last 5 lines
sudo tail -f /var/log/syslog  # follow live, Ctrl+C to stop
logger "message"              # write a test line into syslog
```

`tail -f` takes over the terminal. To test it, open a second tab and SSH in again.
When I SSH'd in, syslog recorded it: `Started session-4.scope - Session 4 of User malzi`.

### Writing files

```bash
echo "one" > a.txt     # > replaces the file
echo "two" >> a.txt    # >> adds to the end
```

`echo` adds a newline at the end, which is why appended text lands on a new line. `echo -n` leaves it off.

### Finding files

```bash
find /etc -name "*ssh*.conf"     # * means anything, including nothing
sudo find /var/log -mmin -60     # changed less than 60 min ago
```

| Pattern | Matches |
|---|---|
| `ssh*.conf` | starts with ssh |
| `*ssh.conf` | ssh right before .conf |
| `*ssh*.conf` | ssh anywhere, ends in .conf |

For `-mmin`: `60` is exactly, `+60` is more than, `-60` is less than.
`man <command>` opens the manual. `/` searches, `q` quits.

---

## 2. Permissions

### Reading `ls -l`

```
-rwxr-x---  1  bob  devs  ...  deploy.sh
│└┬┘└┬┘└┬┘     │    │
│ │  │  │      │    └── group
│ │  │  │      └── owner
│ │  │  └── others
│ │  └── group
│ └── owner
└── type: - file, d directory
```

| | On a file | On a directory |
|---|---|---|
| r | read it | list names inside |
| w | change it | create or delete files inside |
| x | run it | enter it, and reach anything inside |

**Key lesson:** a directory needs `x` to get to anything inside, even if the files themselves are readable. With `drwxr--r--`, another user can see the names but can't `cd` in or `cat` the files. "The file is 644, why can't the app read it?" usually means a folder along the path is missing `x`.

### chmod

r = 4, w = 2, x = 1. Add them up for owner, group and others.

| Number | Letters | Typical use |
|---|---|---|
| 755 | rwxr-xr-x | directories, scripts |
| 644 | rw-r--r-- | normal files |
| 700 | rwx------ | private directory |
| 600 | rw------- | private file (keys, secrets) |
| 640 | rw-r----- | file one group needs to read |
| 444 | r--r--r-- | read-only for everyone |

```bash
chmod 755 dir
chmod u+x script.sh   # u owner, g group, o others; + add, - remove
```

New files never get `x` by default, so scripts always need `chmod u+x` before `./script.sh` works. Check first with `ls -l`.

### chown

```bash
sudo chown deploy file           # owner only
sudo chown :deploy file          # group only
sudo chown deploy:deploy file    # both
```

Needs sudo, because normal users can't give files away.

### umask

The default permissions taken away from new files. With `022`, new files are 644 and new directories are 755.

---

## 3. Users, groups and sudo

```bash
whoami                         # my username
id                             # my uid, gid and all groups
groups tester                  # someone else's groups
grep malzi /etc/passwd         # my line: name:x:uid:gid:full name:home:shell
echo $SHELL                    # my shell
sudo adduser tester            # make a user (Ubuntu's friendly version)
sudo groupadd qa               # make a group
sudo usermod -aG qa tester     # ADD tester to qa
su - tester                    # switch user, exit to go back
sudo passwd tester             # reset a password
sudo deluser --remove-home tester
```

**Always `-aG` together.** `-G` alone replaces the user's groups. Doing that to my own account could remove me from `sudo`.

### sudo

- Runs one command as root. Root ignores normal permissions completely.
- On Ubuntu, only members of the `sudo` group can use it.
- A non-sudo user gets `I'm sorry tester. I'm afraid I can't do that` (sudo-rs) or `tester is not in the sudoers file` (classic sudo).
- Failed attempts are logged: `sudo grep tester /var/log/auth.log`
- Edit sudoers only with `sudo visudo`. It checks for mistakes before saving. A broken sudoers file stops sudo working for everyone.

### Why services run as their own user

If the web server is hacked, the attacker only gets what `www-data` can do, not the whole server. This limits the blast radius. It's **least privilege**: give the minimum access needed and nothing more.

---

## 4. Problems I hit

### Couldn't delete a user

```
userdel: user alice is currently used by process 2329
```

```bash
ps -u alice                       # what is alice running
ps -p 2329 -o pid,user,cmd        # it was -bash, an open su - alice session
sudo pkill -u alice               # didn't work: SIGTERM, bash ignored it
sudo pkill -9 -u alice            # SIGKILL, forced it
sudo deluser --remove-home alice
```

Lesson: if something can't be removed or changed, find what's using it, then stop it.
- SIGTERM (15) is the default, a polite "please stop". Programs can ignore it.
- SIGKILL (9) forces it now. Use only when SIGTERM fails.

---

## 5. Task: a deploy user

Goal: `/srv/app` that only `deploy` can write to, but others can look inside.

```bash
sudo adduser deploy

# deploy can't create things in /srv, because /srv is drwxr-xr-x root root
# and deploy can't use sudo. So the admin sets it up, then hands it over.
sudo mkdir /srv/app
sudo chown deploy:deploy /srv/app
sudo chmod 755 /srv/app

# as deploy: works
su - deploy
touch /srv/app/hello.py
exit

# as malzi, WITHOUT sudo: cd and ls work, creating fails
cd /srv/app
ls
touch hello.sh       # Permission denied
```

Don't test step 5 with sudo: root ignores permissions, so it would succeed and prove nothing.

Mistake I made: tried `chmod 744`. That removes `x` from group and others, so they can't enter the folder at all. 755 was right.

### Reading `ls -ld /srv/app`

```
drwxr-xr-x 2 deploy deploy 4096 Oct 26 15:54 /srv/app
```

| Part | Meaning |
|---|---|
| `d` | directory |
| `rwx` | owner: list, create/delete, enter |
| `r-x` | group: list, enter |
| `r-x` | others: list, enter |
| `2` | link count (its name in /srv, plus `.` inside it) |
| `deploy` | owner |
| `deploy` | group |
| `4096` | size of the directory's own name list, one 4 KB block. Use `du -sh` for contents |
| `Oct 26 15:54` | last modified |
| `/srv/app` | name |

`ls -ld` shows the directory itself, rather than listing what's inside it.

---

## 6. Scenarios

### Web server can't read a file

`www-data` can't read `-rw------- bob bob index.html`.

1. `chmod o+r index.html` (644): works, but every user can now read it
2. `sudo chown bob:www-data index.html` + `chmod 640`: only the web server's group can read it

Option 2 is safer (least privilege). Also check www-data has `x` on every folder in the path.

### "The app stopped writing logs to /var/log/myapp/"

| # | Command | Looking for |
|---|---|---|
| 1 | `systemctl status myapp` | is it even running |
| 2 | `ps aux \| grep myapp` | which user it runs as |
| 3 | `ls -ld /var/log/myapp` | can that user write to and enter the folder |
| 4 | `ls -l /var/log/myapp/` | are existing log files owned by and writable by that user |
| 5 | `journalctl -u myapp -n 50` | the app's own errors, e.g. Permission denied |
| 6 | `df -h /var/log` | disk full looks very similar |

It **stopped** working, so ask what changed: a deploy, a config change, a chown or chmod, or log rotation creating files with the wrong owner.

Fix with least privilege: `sudo chown myapp:myapp /var/log/myapp`, `sudo chmod 755 /var/log/myapp`.