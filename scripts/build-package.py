#!/usr/bin/env python3

import argparse
import io
import json
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import zipfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
PAYLOAD_FILES = ('gitea_version', 'LICENSE', 'README.md')
ARCHITECTURES = ('x86-64', 'arm64')


def metadata(root: Path = ROOT) -> tuple[dict[str, Any], str]:
    """Validate version consistency and return the configuration and release notes.

    Raises ValueError when a version marker or the first changelog heading does
    not match the package version. Older changelog entries are excluded
    """
    config = json.loads((root / 'CONTROL/config.json').read_text(encoding='utf-8'))
    version = (root / 'gitea_version').read_text(encoding='utf-8').strip()
    package_version = config['general']['version']
    if not re.fullmatch(re.escape(version) + r'\.r\d{2}', package_version):
        raise ValueError('Inconsistent Gitea and package versions')
    for filename, marker in (
        ('README.md', f'__Gitea version__: _`{version}`_'),
        ('CONTROL/description.txt', f'Gitea current version: {version} -'),
        ('CONTROL/description-fr.txt', f'Version actuelle de Gitea : {version} -'),
    ):
        if marker not in (root / filename).read_text(encoding='utf-8'):
            raise ValueError(f'Inconsistent version in {filename}')
    changelog = (root / 'CONTROL/changelog.txt').read_text(encoding='utf-8')
    heading, _, body = changelog.partition('\n')
    if heading.strip() != f'Version {package_version}':
        raise ValueError('Changelog must start with the current package version')
    notes = re.split(r'(?m)^Version ', body, maxsplit=1)[0].strip() + '\n'
    return config, notes


def prepare_staging(root: Path, stage: Path, config: dict[str, Any]) -> None:
    """Copy the package allowlist and write the architecture-specific configuration"""
    shutil.copytree(root / 'CONTROL', stage / 'CONTROL')
    for name in PAYLOAD_FILES:
        shutil.copy2(root / name, stage / name)
    (stage / 'CONTROL/config.json').write_text(
        json.dumps(config, indent=2) + '\n', encoding='utf-8'
    )


def read_tar_member(archive: tarfile.TarFile, name: str) -> bytes:
    """Read a required file without extracting archive contents onto disk"""
    member = archive.extractfile(name)
    if member is None:
        raise ValueError(f'Archive member is not a file: {name}')
    with member:
        return member.read()


def verify_package(
    artifact: Path, config: dict[str, Any], expected_version: str
) -> None:
    """Check APK integrity, configuration, executable scripts and payload allowlist.

    The upstream CLI can exit successfully after returning an error, so its exit
    code alone is insufficient. Invalid or missing archives raise an exception
    """
    with zipfile.ZipFile(artifact) as archive:
        if archive.testzip() is not None:
            raise ValueError('Corrupt APK archive')
        if archive.read('apkg-version').strip() != b'2.0':
            raise ValueError('Unexpected APK format')
        with tarfile.open(
            fileobj=io.BytesIO(archive.read('control.tar.gz')), mode='r:gz'
        ) as control:
            packed_config = json.loads(read_tar_member(control, './config.json'))
            if packed_config != config:
                raise ValueError('Unexpected packaged configuration')
            for member in control.getmembers():
                if member.name.endswith('.sh') and (member.mode & 0o111) != 0o111:
                    raise ValueError(f'Script is not executable: {member.name}')
        with tarfile.open(
            fileobj=io.BytesIO(archive.read('data.tar.gz')), mode='r:gz'
        ) as data:
            files = {member.name for member in data.getmembers() if member.isfile()}
            if files != {f'./{name}' for name in PAYLOAD_FILES}:
                raise ValueError(f'Unexpected package payload: {files}')
            packed_version = read_tar_member(data, './gitea_version').decode('utf-8')
            if packed_version.strip() != expected_version:
                raise ValueError('Unexpected packaged Gitea version')


def build(architecture: str, output: Path, root: Path = ROOT) -> Path:
    """Run the ASUSTOR tool against a temporary copy and return the verified APK"""
    config, _ = metadata(root)
    config['general']['architecture'] = architecture
    expected_version = (root / 'gitea_version').read_text(encoding='utf-8').strip()
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix='gitea-package-') as temporary:
        stage = Path(temporary) / 'app'
        prepare_staging(root, stage, config)
        subprocess.run(
            [
                sys.executable,
                str(root / 'tools/apkg-tools_py3.py'),
                'create', str(stage),
                '--destination', str(output),
            ],
            check=True,
        )

    general = config['general']
    filename = f"{general['package']}_{general['version']}_{architecture}.apk"
    artifact = output / filename
    verify_package(artifact, config, expected_version)
    return artifact


def main() -> None:
    """Dispatch the CLI metadata mode prints only the version for workflow capture"""
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        '--architecture', choices=ARCHITECTURES, help='Target ASUSTOR architecture'
    )
    parser.add_argument(
        '--output', type=Path, default=ROOT / 'dist',
        help='Output directory (default: repository dist/)',
    )
    parser.add_argument(
        '--metadata', action='store_true',
        help='Export release-notes.md and print the package version instead of building',
    )
    args = parser.parse_args()
    if args.metadata:
        config, notes = metadata()
        args.output.mkdir(parents=True, exist_ok=True)
        (args.output / 'release-notes.md').write_text(notes, encoding='utf-8')
        print(config['general']['version'])
    elif args.architecture:
        print(build(args.architecture, args.output))
    else:
        parser.error('Specify --architecture or --metadata')


if __name__ == '__main__':
    main()
