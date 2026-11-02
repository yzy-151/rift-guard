"""Bind acceptance evidence to the game sources and binaries actually tested."""
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def source_digest():
    digest = hashlib.sha256()
    files = [path for path in (ROOT / 'game').rglob('*')
             if path.is_file() and '.godot' not in path.parts
             and path.suffix in {'.gd', '.gdshader', '.json', '.tres', '.tscn', '.godot', '.cfg', '.xlsx'}]
    # The editor prefers the authoring workbook; exported games use game/data.
    authoring_workbook = ROOT / 'content/game_config.xlsx'
    if authoring_workbook.is_file():
        files.append(authoring_workbook)
    for path in sorted(files):
        digest.update(path.relative_to(ROOT).as_posix().encode('utf-8') + b'\0')
        # Git's Windows newline conversion must not invalidate source identity.
        content = path.read_bytes()
        digest.update(content if path.suffix == '.xlsx' else content.replace(b'\r\n', b'\n'))
        digest.update(b'\0')
    return digest.hexdigest()


def identity(executable, release=False):
    executable = Path(executable)
    binaries = {executable.name: sha256(executable)}
    if release:
        binaries[executable.with_suffix('.pck').name] = sha256(executable.with_suffix('.pck'))
    return {'source_sha256': source_digest(), 'binaries': binaries}


if __name__ == '__main__':
    import argparse
    import json

    parser = argparse.ArgumentParser()
    parser.add_argument('--build-directory', required=True, type=Path)
    args = parser.parse_args()
    executable = args.build_directory / 'RiftGuard-V101.exe'
    (args.build_directory / 'build-identity.json').write_text(
        json.dumps(identity(executable, True), indent=2), encoding='utf-8')
