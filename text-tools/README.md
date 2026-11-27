# Text tools + Python for ops

Same log report done two ways: a shell pipeline and a Python script.

| File | What it does |
|---|---|
| `gen_log.py` | makes a fake nginx `access.log` with 1000 random requests |
| `report.sh` | status code counts and top 5 IPs, using cut, sort and uniq |
| `report.py` | the same report in Python, with argparse, pathlib, logging, subprocess and Counter |
| `folder_size.py` | practice: prints a folder's size with `du -sh` via subprocess |

## Usage

```bash
python3 gen_log.py
./report.sh access.log
python3 report.py access.log --top 3
python3 report.py --help
```

Both reports give the same numbers on the same log. A missing file or argument logs an error and exits with 1.

Notes: [`linux/04-text-tools-python-ops.md`](../linux/04-text-tools-python-ops.md)
