from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "database" / "manifest.txt"
OUTPUT = ROOT / "build" / "koha_lite_workbench_build.sql"


def main():
    paths = []
    for raw_line in MANIFEST.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        path = ROOT / line
        if not path.is_file():
            raise FileNotFoundError(path)
        paths.append((line, path))

    sections = [
        "-- KOHA-Lite Workbench build generated from database/manifest.txt",
        "-- Safe behavior: CREATE DATABASE fails if koha_lite already exists.",
        "-- No existing schema is dropped or replaced by this script.",
        "SET sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';",
        "CREATE DATABASE koha_lite CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;",
        "USE koha_lite;",
        "",
    ]
    for relative, path in paths:
        sections.extend([
            "-- ============================================================================",
            f"-- BEGIN {relative}",
            "-- ============================================================================",
            path.read_text(encoding="utf-8").rstrip(),
            f"-- END {relative}",
            "",
        ])
    sections.extend([
        "SELECT 'KOHA_LITE_BUILD_COMPLETE' AS BuildStatus, DATABASE() AS DatabaseName, VERSION() AS MySQLVersion;",
        "",
    ])
    OUTPUT.write_text("\n".join(sections), encoding="utf-8", newline="\n")
    print(f"Wrote {OUTPUT} with {len(paths)} manifest files")


if __name__ == "__main__":
    main()
