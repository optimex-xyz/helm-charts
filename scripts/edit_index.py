#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Edit Helm Chart's download URL in index.yaml
# Author: @vietanhduong

import argparse
import os
import sys
from pathlib import Path
import yaml

def env(key: str, default="") -> str:
    # Get environment variable, return default vaule (empty string)
    # if the key does not exist else return value of the key.
    return os.getenv(key) or default


def err(msg, **kwargs):
    # Print error message in Stderr
    print(f"ERROR: {msg}", file=sys.stderr, **kwargs)


def info(msg, **kwargs):
    # Print info message in Stdout
    print(f"INFO: {msg}", file=sys.stdout, **kwargs)


def cat(path: str) -> str:
    # Open the file in text mode, read it, and close the file.
    f = Path(path)
    if not f.is_file():
        err(f"{path}: No such file or directory")
        exit(1)
    return f.read_text()


def write(path: str, content: str) -> int:
    # Write content file to input path as text
    #
    f = Path(path)
    if not f.is_file():
        err(f"{path}: No such file or directory")
        exit(1)
    return f.write_text(content)


# [BEGIN] edit_index
parser = argparse.ArgumentParser(
    prog='edit_index', description="Edit Helm Chart's download URL.")
parser.add_argument(
    '--path', help='Path to index.yaml. Default: $INDEX_PATH (Current directory)', default=env('INDEX_PATH'))
parser.add_argument(
    '--new_url', help='New download url. Default: $NEW_URL (Current directory)', default=env('NEW_URL'))
parser.add_argument('--all', action='store_true', help='Repleace all. Default edit_index just repleaces the latest version of each chart. (Not recommend)')

args = vars(parser.parse_args())

index_path = args['path'] or '.'
new_url = args['new_url'] or '.'
replace_all = args['all']

# Validate index path
if not os.path.exists(index_path):
    err(f'Path {index_path} does not exist')
    exit(1)

# If the index path is a directory, we can try and fix it
abs_path = os.path.abspath(index_path)
if os.path.isdir(index_path):
    # List all files in 'index_path' WITHOUT recursive
    files = os.listdir(index_path)
    if 'index.yaml' in files:
        index_path = os.path.join(abs_path, 'index.yaml')
    else:
        # If the directory does not contain index file. Just exist
        # with code 1
        err(f'Path {abs_path} does not contain index.yaml')
        exit(1)
elif os.path.isfile(index_path):
    # The index file must be endwith index.yaml
    if os.path.basename(index_path) != 'index.yaml':
        err(f"The file name must be 'index.yaml'")
        exit(1)
else:
    err(f'Path: {abs_path} is a special file (socket, FIFO, device file)')
    exit(1)

index_content = None

try:
    index_content = yaml.safe_load(cat(index_path))
except yaml.YAMLError:
    err('Parse index.yaml failed')
    exit(1)

def repleace_urls(dest, src):
  out_urls = []
  for url in src:
    # E.g: <chart_name>-<chart_version>.tgz
    package = os.path.basename(url)
    out_urls.append(os.path.join(dest, package))
  return out_urls

entries = index_content.get('entries', {})
for key in entries:
    chart = entries.get(key, [])
    # Just skip if chart containts no versions
    if not len(chart):
      continue
    # If replace all is false
    # Repleace the latest (first element) version of the chart
    if not replace_all:
      urls = chart[0].get('urls', [])
      chart[0]['urls'] = repleace_urls(new_url, urls)
      entries[key] = chart
      continue

    # Replace all urls
    # This will reduce performance if index.yaml is large in size. (Not recommend)
    out_version = []
    for version in chart:
        urls = version.get('urls', [])
        version['urls'] = repleace_urls(new_url, urls)
        out_version.append(version)
    entries[key] = out_version

# Rewirte key
index_content['entries'] = entries

write(index_path, yaml.dump(index_content, default_flow_style=False))
info("Done!!")
exit(0)
# [END] edit_index
