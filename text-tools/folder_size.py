import argparse
import logging
import subprocess
from pathlib import Path
import sys

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
a = argparse.ArgumentParser(description="Show the size of a folder")
a.add_argument("folder_path")
args = a.parse_args()

p = Path(args.folder_path)
if not p.is_dir():
    logging.error(f"folder not found: {p}")
    sys.exit(1)
else:
    result = subprocess.run(["du", "-sh", p], capture_output=True, text=True, check=True)
    print(result.stdout.strip())
