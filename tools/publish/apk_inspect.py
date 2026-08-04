"""Read what is actually inside an APK.

A store upload is judged by its contents, not its filename. `Airo-TV-0.0.6.apk`
reads as a universal build and is arm64-only; APKPure then labels it
"Architecture: universal" on its own. Nothing in the release chain checks, so a
build-config change could quietly ship a fat APK to a size-budgeted TV listing,
or ship an arm64 slice to devices that cannot run it.
"""

from __future__ import annotations

import zipfile
from dataclasses import dataclass
from pathlib import Path

#: ABI directory names Android recognises under lib/.
KNOWN_ABIS = frozenset(
    {"arm64-v8a", "armeabi-v7a", "armeabi", "x86", "x86_64", "mips", "mips64"}
)


@dataclass(frozen=True)
class ApkContents:
    path: Path
    abis: frozenset[str]
    native_bytes: int
    total_bytes: int

    @property
    def is_universal(self) -> bool:
        """True when the APK carries native code for more than one ABI."""
        return len(self.abis) > 1

    def describe(self) -> str:
        listed = ", ".join(sorted(self.abis)) if self.abis else "no native libs"
        return f"{self.path.name}: {listed} ({self.native_bytes / 1e6:.1f} MB native)"


def inspect_apk(path: Path) -> ApkContents:
    abis: set[str] = set()
    native = 0
    with zipfile.ZipFile(path) as archive:
        for info in archive.infolist():
            parts = info.filename.split("/")
            if len(parts) >= 3 and parts[0] == "lib" and parts[1] in KNOWN_ABIS:
                abis.add(parts[1])
                native += info.file_size
    return ApkContents(
        path=path,
        abis=frozenset(abis),
        native_bytes=native,
        total_bytes=path.stat().st_size,
    )


#: What each ABI actually reaches, in device terms rather than architecture
#: names. Used to state a listing's coverage in a release summary, so an
#: excluded device class is visible at publish time instead of discovered by a
#: user whose install fails.
ABI_DEVICE_CLASSES = {
    "arm64-v8a": "64-bit ARM: Fire TV Stick 4K / 4K Max, current Android TV boxes, modern phones",
    "armeabi-v7a": "32-bit ARM: older Fire TV Sticks (2nd gen, Lite), legacy Android TV boxes",
    "x86_64": "64-bit x86: emulators, some Chromebooks",
    "x86": "32-bit x86: old emulators",
}


def coverage_report(served: frozenset[str], candidates: frozenset[str]) -> dict:
    """Describe which device classes a listing serves, and which it does not.

    `candidates` is every ABI the release built, so "not served" means an
    artifact exists for those devices somewhere else -- on the GitHub release --
    rather than that the devices are unsupported outright.
    """
    missing = sorted(candidates - served)
    return {
        "servedAbis": sorted(served),
        "served": [ABI_DEVICE_CLASSES.get(a, a) for a in sorted(served)],
        "notServedAbis": missing,
        "notServed": [ABI_DEVICE_CLASSES.get(a, a) for a in missing],
    }
