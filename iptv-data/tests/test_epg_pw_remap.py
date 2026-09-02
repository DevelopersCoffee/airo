import xml.etree.ElementTree as ET

from src.epg_pw_remap import normalize_name, remap_epg_pw_xmltv


def _catalog(*channels: dict[str, object]) -> dict[str, object]:
    return {"channels": list(channels)}


def _mtv_source_xml() -> bytes:
    return b"""<tv>
<channel id="543480"><display-name>MTV</display-name></channel>
<programme channel="543480" start="20260902090000 +0000" stop="20260902100000 +0000">
  <title>Hustle</title>
</programme>
</tv>"""


def test_normalize_name_strips_quality_suffix_and_punctuation() -> None:
    assert normalize_name("MTV HD") == "mtv"
    assert normalize_name("MTV (SD)") == "mtv"
    assert normalize_name("B4U Music") == normalize_name("b4u-music")


def test_remaps_numeric_id_to_catalog_id_and_splits_by_country() -> None:
    catalog = _catalog({"id": "MTV.in", "name": "MTV", "country": "IN"})

    result = remap_epg_pw_xmltv(_mtv_source_xml(), catalog)

    assert set(result) == {"IN", "ALL"}
    for xml_bytes in (result["IN"], result["ALL"]):
        root = ET.fromstring(xml_bytes)
        channel_ids = {el.get("id") for el in root.findall("channel")}
        programme_channels = {el.get("channel") for el in root.findall("programme")}
        assert channel_ids == {"MTV.in"}
        assert programme_channels == {"MTV.in"}
        assert root.find("./programme/title").text == "Hustle"
        # The raw epg.pw numeric id must never appear in output.
        assert "543480" not in ET.tostring(root, encoding="unicode")


def test_unmatched_channel_is_dropped() -> None:
    catalog = _catalog({"id": "MTV.in", "name": "MTV", "country": "IN"})
    source = b"""<tv>
<channel id="999999"><display-name>Totally Unknown Channel</display-name></channel>
<programme channel="999999" start="20260902090000 +0000" stop="20260902100000 +0000">
  <title>Nothing</title>
</programme>
</tv>"""

    result = remap_epg_pw_xmltv(source, catalog)

    for xml_bytes in result.values():
        root = ET.fromstring(xml_bytes)
        assert root.findall("channel") == []
        assert root.findall("programme") == []


def test_channel_id_already_matching_catalog_is_kept() -> None:
    catalog = _catalog({"id": "MTV.in", "name": "MTV", "country": "IN"})
    source = b"""<tv>
<channel id="MTV.in"><display-name>MTV</display-name></channel>
<programme channel="MTV.in" start="20260902090000 +0000" stop="20260902100000 +0000">
  <title>Hustle</title>
</programme>
</tv>"""

    result = remap_epg_pw_xmltv(source, catalog)

    root = ET.fromstring(result["IN"])
    assert {el.get("id") for el in root.findall("channel")} == {"MTV.in"}


def test_name_collision_picks_lexicographically_smaller_id_deterministically() -> None:
    catalog = _catalog(
        {"id": "MTV.us", "name": "MTV", "country": "US"},
        {"id": "MTV.in", "name": "MTV", "country": "IN"},
    )

    result = remap_epg_pw_xmltv(_mtv_source_xml(), catalog)

    # "MTV.in" < "MTV.us" lexicographically -- the pick must be stable
    # across runs given the same catalog, regardless of catalog list order.
    assert set(result) == {"IN", "ALL"}
    root = ET.fromstring(result["IN"])
    assert {el.get("id") for el in root.findall("channel")} == {"MTV.in"}


def test_channels_with_no_country_bucket_under_zz() -> None:
    catalog = _catalog({"id": "MTV.zz", "name": "MTV"})

    result = remap_epg_pw_xmltv(_mtv_source_xml(), catalog)

    assert set(result) == {"ZZ", "ALL"}


def test_all_is_the_union_of_every_country() -> None:
    catalog = _catalog(
        {"id": "MTV.in", "name": "MTV", "country": "IN"},
        {"id": "AlJazeera.qa", "name": "Al Jazeera", "country": "QA"},
    )
    source = b"""<tv>
<channel id="543480"><display-name>MTV</display-name></channel>
<channel id="1"><display-name>Al Jazeera</display-name></channel>
<programme channel="543480" start="20260902090000 +0000" stop="20260902100000 +0000">
  <title>Hustle</title>
</programme>
<programme channel="1" start="20260902090000 +0000" stop="20260902100000 +0000">
  <title>NEWSHOUR</title>
</programme>
</tv>"""

    result = remap_epg_pw_xmltv(source, catalog)

    assert set(result) == {"IN", "QA", "ALL"}
    all_root = ET.fromstring(result["ALL"])
    assert {el.get("id") for el in all_root.findall("channel")} == {
        "MTV.in",
        "AlJazeera.qa",
    }
    assert {el.get("channel") for el in all_root.findall("programme")} == {
        "MTV.in",
        "AlJazeera.qa",
    }
