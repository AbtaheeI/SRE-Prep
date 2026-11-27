import argparse
import logging
import subprocess
from pathlib import Path
import sys
from collections import Counter

logging.basicConfig(level=logging.INFO, format= "%(asctime)s %(levelname)s %(message)s")
parser = argparse.ArgumentParser(description="Calculation of the Count of Status Code and IP Addresses")
parser.add_argument("file")
parser.add_argument("--top", type=int, default=5)
args = parser.parse_args()

p = Path(args.file)
if not p.is_file():
    logging.error(f"{p} does not exist")
    sys.exit(1)
else:
    result = subprocess.run(["wc", "-l", p], capture_output=True, text=True, check=True)
    logging.info(f"{p} has {result.stdout.split()[0]} lines")

    status = []
    ips = []
    for line in p.open():
        r = line.split()
        status.append(r[8])
        ips.append(r[0])

    print("== Status codes ==")
    status_codes = Counter(status)
    for code, count in status_codes.most_common():
        print(count, code)

    print(f"== Top {args.top} IPs ==")
    ip_codes = Counter(ips)
    for ip, count in ip_codes.most_common(args.top):
        print(count, ip)
