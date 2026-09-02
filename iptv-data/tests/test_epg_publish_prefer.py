import gzip
import hashlib
import json
from pathlib import Path

from src.epg_publish_prefer import (
    programme_count_in_file,
    programme_count_in_gzip,
    publish_all_guide,
    select_countries_to_publish,
)

_XML_TEMPLATE = """<tv>
<channel id="Chan.{cc}"><display-name>Chan</display-name></channel>
{programmes}
</tv>"""

_PROGRAMME = (
    '<programme channel="Chan.{cc}" start="20260902090000 +0000" '
    'stop="20260902100000 +0000"><title>P{i}</title></programme>'
)


def _xml(cc: str, count: int) -> bytes:
    programmes = "\n".join(_PROGRAMME.format(cc=cc, i=i) for i in range(count))
    return _XML_TEMPLATE.format(cc=cc, programmes=programmes).encode("utf-8")


def test_country_with_no_existing_artifact_is_always_selected(tmp_path: Path) -> None:
    remap_dir = tmp_path / "remap"
    remap_dir.mkdir()
    (remap_dir / "QA.xml").write_bytes(_xml("qa", 1))
    (remap_dir / "ALL.xml").write_bytes(_xml("qa", 1))
    published = tmp_path / "published"
    published.mkdir()

    selected = select_countries_to_publish(
        remap_dir=remap_dir, published_directory=published
    )

    assert selected == ["QA"]


def test_priority_country_only_wins_when_remap_covers_at_least_as_much(
    tmp_path: Path,
) -> None:
    remap_dir = tmp_path / "remap"
    remap_dir.mkdir()
    published = tmp_path / "published"
    published.mkdir()
    (remap_dir / "ALL.xml").write_bytes(_xml("in", 1))

    # Existing grab has more programmes than the remap -- keep the grab.
    (remap_dir / "IN.xml").write_bytes(_xml("in", 2))
    (published / "guide_IN.xml.gz").write_bytes(
        gzip.compress(_xml("in", 5), mtime=0)
    )
    assert select_countries_to_publish(
        remap_dir=remap_dir, published_directory=published
    ) == []

    # Remap now covers at least as much -- prefer it.
    (remap_dir / "IN.xml").write_bytes(_xml("in", 5))
    assert select_countries_to_publish(
        remap_dir=remap_dir, published_directory=published
    ) == ["IN"]


def test_priority_country_with_no_existing_artifact_is_selected_when_nonempty(
    tmp_path: Path,
) -> None:
    remap_dir = tmp_path / "remap"
    remap_dir.mkdir()
    (remap_dir / "IN.xml").write_bytes(_xml("in", 1))
    (remap_dir / "ALL.xml").write_bytes(_xml("in", 1))
    published = tmp_path / "published"
    published.mkdir()

    assert select_countries_to_publish(
        remap_dir=remap_dir, published_directory=published
    ) == ["IN"]


def test_empty_priority_country_remap_is_never_selected(tmp_path: Path) -> None:
    remap_dir = tmp_path / "remap"
    remap_dir.mkdir()
    (remap_dir / "IN.xml").write_bytes(_xml("in", 0))
    (remap_dir / "ALL.xml").write_bytes(_xml("in", 0))
    published = tmp_path / "published"
    published.mkdir()

    assert select_countries_to_publish(
        remap_dir=remap_dir, published_directory=published
    ) == []


def test_programme_count_helpers(tmp_path: Path) -> None:
    plain = tmp_path / "plain.xml"
    plain.write_bytes(_xml("in", 3))
    assert programme_count_in_file(plain) == 3
    assert programme_count_in_file(tmp_path / "missing.xml") == 0

    gz = tmp_path / "guide_IN.xml.gz"
    gz.write_bytes(gzip.compress(_xml("in", 4), mtime=0))
    assert programme_count_in_gzip(gz) == 4
    assert programme_count_in_gzip(tmp_path / "missing.xml.gz") == 0


def test_publish_all_guide_writes_gzip_and_manifest_checksum(tmp_path: Path) -> None:
    output_directory = tmp_path / "output"
    manifest_path = tmp_path / "manifest.json"
    manifest_path.write_text('{"files": {}, "fileChecksums": {}}', encoding="utf-8")
    all_xml = _xml("in", 2)

    checksum = publish_all_guide(
        all_xml_bytes=all_xml,
        output_directory=output_directory,
        manifest_path=manifest_path,
    )

    published = output_directory / "guide_ALL.xml.gz"
    assert published.exists()
    assert gzip.decompress(published.read_bytes()) == all_xml
    assert checksum == hashlib.sha256(published.read_bytes()).hexdigest()

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    assert manifest["files"]["guide_ALL"] == "guide_ALL.xml.gz"
    assert manifest["fileChecksums"]["guide_ALL"] == checksum
