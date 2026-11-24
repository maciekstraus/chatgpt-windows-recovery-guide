#!/usr/bin/env python3
"""Extract user/assistant text from a local, uncompressed JSONL backup."""
import argparse
import json
from pathlib import Path


def messages(record):
    if not isinstance(record, dict) or record.get('type') != 'response_item':
        return None
    item = record.get('payload')
    if not isinstance(item, dict) or item.get('type') != 'message':
        return None
    role = item.get('role')
    if role not in ('user', 'assistant'):
        return None
    content = item.get('content')
    if not isinstance(content, list):
        return None
    parts = [part['text'] for part in content if isinstance(part, dict)
             and part.get('type') in ('input_text', 'output_text', 'text')
             and isinstance(part.get('text'), str)]
    return (role, '\n'.join(parts)) if parts else None


def recover(source, destination, max_bytes=2_000_000):
    source = Path(source).resolve(strict=True)
    destination = Path(destination).resolve()
    if not source.is_file() or source.suffix.lower() != '.jsonl':
        raise ValueError('Select an uncompressed .jsonl backup file')
    if not 1 <= max_bytes <= 64 * 1024 * 1024:
        raise ValueError('max_bytes must be between 1 and 67108864')
    stats = dict(records=0, oversized=0, malformed=0, ignored=0,
                 user=0, assistant=0)
    # Exclusive directory creation prevents overwriting an earlier export.
    with source.open('rb') as src:
        destination.mkdir(mode=0o700, parents=False, exist_ok=False)
        with (destination / 'transcript.txt').open('x', encoding='utf-8',
                                                  errors='backslashreplace') as out:
            while True:
                line = src.readline(max_bytes + 1)
                if not line:
                    break
                stats['records'] += 1
                if len(line) > max_bytes:
                    stats['oversized'] += 1
                    # Drain the same physical line in bounded chunks.
                    while line and not line.endswith(b'\n'):
                        line = src.readline(65536)
                    continue
                try:
                    record = json.loads(line.decode('utf-8-sig'))
                except (UnicodeError, ValueError, RecursionError):
                    stats['malformed'] += 1
                    continue
                message = messages(record)
                if message is None:
                    stats['ignored'] += 1
                    continue
                role, body = message
                out.write(f"\n--- {role.upper()} | record {stats['records']} ---\n{body}\n")
                stats[role] += 1
    with (destination / 'report.json').open('x', encoding='utf-8') as report:
        json.dump(stats, report, indent=2)
        report.write('\n')
    return stats


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='Uncompressed JSONL backup')
    parser.add_argument('destination', type=Path, help='New private output directory')
    parser.add_argument('--max-line-bytes', type=int, default=2_000_000,
                        help='Maximum physical record size, including newline')
    args = parser.parse_args()
    try:
        stats = recover(args.source, args.destination, args.max_line_bytes)
    except (OSError, ValueError) as exc:
        parser.exit(1, f'Error: {exc}\nOutput, if created, may be incomplete.\n')
    print(json.dumps(stats, indent=2))


if __name__ == '__main__':
    main()
