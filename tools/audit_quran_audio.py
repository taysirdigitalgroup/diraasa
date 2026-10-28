#!/usr/bin/env python3
"""Check local Hafs MP3 files before publishing. Never claims semantic verification."""
import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys


def inspect_file(path, root, decode=True):
    relative = path.relative_to(root).as_posix()
    try:
        if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
            raise ValueError('Symbolic link or path outside repository')
        with path.open('rb') as stream:
            prefix = stream.read(1024).lstrip()
        if prefix.startswith((b'version https://git-lfs.github.com/spec/', b'<!DOCTYPE', b'<html', b'{')):
            raise ValueError('Not a standalone MP3 (LFS pointer, HTML or JSON)')
        probe = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'a:0',
            '-show_entries', 'stream=codec_name:format=duration', '-of', 'json', str(path)],
            capture_output=True, text=True, timeout=120, check=True)
        metadata = json.loads(probe.stdout)
        if not metadata.get('streams') or metadata['streams'][0].get('codec_name') != 'mp3':
            raise ValueError('Expected an MP3 audio stream')
        duration = float(metadata['format']['duration'])
        if not 0 < duration < 86400:
            raise ValueError('Invalid audio duration')
        if decode:
            result = subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-i', str(path),
                '-map', '0:a:0', '-f', 'null', '-'], capture_output=True, text=True, timeout=120)
            if result.returncode or result.stderr.strip():
                raise ValueError('MP3 decoding errors')
        digest = hashlib.sha256()
        with path.open('rb') as stream:
            for block in iter(lambda: stream.read(65536), b''):
                digest.update(block)
        stem = path.stem
        return {'file': relative, 'chapter': int(stem[:3]), 'verse': int(stem[3:]),
                'language': path.parent.name.removeprefix('quran-hafs-'), 'bytes': path.stat().st_size,
                'durationSeconds': duration, 'sha256': digest.hexdigest(), 'decoded': decode}
    except Exception as error:
        return {'file': relative, 'error': str(error)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True, help='Local diraasa-quran-sounds repository')
    parser.add_argument('--language', nargs='+', choices=['ar', 'fr', 'en'], default=['ar', 'fr', 'en'])
    parser.add_argument('--surah', type=int)
    parser.add_argument('--verse', type=int, help='Optional single verse (requires --surah)')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--probe-only', action='store_true', help='Skip full decode; weaker check')
    args = parser.parse_args()
    if not args.root.is_dir(): parser.error('Repository directory does not exist')
    if args.surah is not None and not 1 <= args.surah <= 114: parser.error('Surah must be 1..114')
    if args.verse is not None and args.surah is None: parser.error('--verse requires --surah')
    for tool in ['ffprobe'] + ([] if args.probe_only else ['ffmpeg']):
        if not shutil.which(tool): parser.error(f'{tool} must be installed')
    book = json.loads((Path(__file__).resolve().parents[1] / 'assets/devotion/quran_hafs.json').read_text())
    expected = set()
    for chapter in book['chapters']:
        number = chapter['number']
        if args.surah is not None and number != args.surah: continue
        verses = [v['number'] for v in chapter['verses']]
        if number not in [1, 9]: verses = [0] + verses
        if args.verse is not None:
            if args.verse not in verses: parser.error('Verse absent from Hafs text / invalid basmala')
            verses = [args.verse]
        for language in set(args.language):
            expected.update(f'quran-hafs-{language}/{number:03d}{verse:03d}.mp3' for verse in verses)
    missing = sorted(p for p in expected if not (args.root / p).is_file())
    present = sorted(expected - set(missing))
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda p: inspect_file(args.root / p, args.root, not args.probe_only), present))
    errors = [row for row in results if 'error' in row]
    valid = [row for row in results if 'error' not in row]
    report = {'expectedFiles': len(expected), 'checkedFiles': len(results), 'validFiles': len(valid),
        'technicalPassed': not missing and not errors, 'fullDecode': not args.probe_only,
        'semanticMappingVerified': False,
        'note': 'Names, numbering and decoding are technical checks. A human content review must confirm that each recording recites/translates the corresponding verse.',
        'missing': missing, 'errors': errors, 'files': valid}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f"Expected {len(expected)}; valid {len(valid)}; missing {len(missing)}; invalid {len(errors)}")
    return 0 if report['technicalPassed'] else 1

if __name__ == '__main__':
    sys.exit(main())
