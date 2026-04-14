from pathlib import Path
import os
import shutil

import kagglehub

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR.parent / "data"
RAW_DIR = DATA_DIR / "raw"
DATA_DIR.mkdir(parents=True, exist_ok=True)
RAW_DIR.mkdir(parents=True, exist_ok=True)

os.environ["KAGGLEHUB_CACHE"] = str(DATA_DIR)

download_path = Path(kagglehub.dataset_download("rounakbanik/the-movies-dataset"))

for csv_file in download_path.glob("*.csv"):
    shutil.copy2(csv_file, RAW_DIR / csv_file.name)

CACHE_DIR = DATA_DIR / "datasets"
if CACHE_DIR.exists():
    shutil.rmtree(CACHE_DIR)

print("Path to dataset files:", RAW_DIR)
