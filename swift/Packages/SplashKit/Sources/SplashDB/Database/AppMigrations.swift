import GRDB

/// Port of `snd.komelia.db.migrations.AppMigrations` (Flyway V1..V12 under `migrations/app`).
///
/// This is a fresh iOS database, so the Kotlin history is collapsed into the *final* schema of the tables
/// that the iOS app keeps. Table/column names are verbatim. Deliberately not ported:
/// - `KomfSettings` (V10) — Komf integration is out of scope.
/// - `BookColorCorrection`, `BookColorCurves`, `BookColorLevels`, `ColorCurvePresets`, `ColorLevelsPresets` (V5).
/// - `UserFonts` (V4) — EPUB is deferred to v1.1.
/// - `AppSettings.check_for_updates_on_startup` / `update_*` — no in-app updater on iOS.
/// - `ImageReaderSettings.onnx_runtime_*` — ONNX upscaling is out of scope.
/// - The V12 `DROP TABLE Komga*` cleanup (those cache tables never existed here).
enum AppMigrations {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_initial") { db in
            try db.execute(sql: """
                CREATE TABLE AppSettings
                (
                    version               INTEGER NOT NULL PRIMARY KEY,
                    username              TEXT    NOT NULL,
                    serverUrl             TEXT    NOT NULL,
                    card_width            INTEGER NOT NULL,
                    series_page_load_size INTEGER NOT NULL,
                    book_page_load_size   INTEGER NOT NULL,
                    book_list_layout      TEXT    NOT NULL,
                    app_theme             TEXT    NOT NULL
                );

                CREATE TABLE ImageReaderSettings
                (
                    book_id                      TEXT PRIMARY KEY,
                    reader_type                  TEXT    NOT NULL,
                    stretch_to_fit               BOOLEAN NOT NULL,
                    paged_scale_type             TEXT    NOT NULL,
                    paged_reading_direction      TEXT    NOT NULL,
                    paged_page_layout            TEXT    NOT NULL,
                    continuous_reading_direction TEXT    NOT NULL,
                    continuous_padding           REAL    NOT NULL,
                    continuous_page_spacing      INTEGER NOT NULL,
                    crop_borders                 BOOLEAN NOT NULL,
                    flash_on_page_change         BOOLEAN NOT NULL DEFAULT 0,
                    flash_duration               INTEGER NOT NULL DEFAULT 100,
                    flash_every_n_pages          INTEGER NOT NULL DEFAULT 1,
                    flash_with                   TEXT    NOT NULL DEFAULT 'BLACK',
                    downsampling_kernel          TEXT    NOT NULL DEFAULT 'LANCZOS3',
                    linear_light_downsampling    BOOLEAN NOT NULL DEFAULT 0,
                    upsampling_mode              TEXT    NOT NULL DEFAULT 'CATMULL_ROM',
                    load_thumbnail_previews      BOOLEAN NOT NULL DEFAULT 1,
                    volume_keys_navigation       BOOLEAN NOT NULL DEFAULT 0
                );

                -- Schema only for now: EPUB reading lands in v1.1. Both settings columns are JSON blobs.
                CREATE TABLE EpubReaderSettings
                (
                    book_id             TEXT PRIMARY KEY,
                    reader_type         TEXT NOT NULL,
                    komga_settings_json TEXT NOT NULL,
                    ttsu_settings_json  TEXT NOT NULL
                );

                -- `filters` is a JSON array of HomeScreenFilter (same as the Exposed json<> column).
                CREATE TABLE HomeScreenFilters
                (
                    version INTEGER NOT NULL PRIMARY KEY,
                    filters TEXT    NOT NULL
                );
                """)
        }
        // [NUEVO] Private (hidden) content — iOS-only, no Kotlin original. Appended, never edit v1.
        migrator.registerMigration("v2_privacy") { db in
            try db.execute(sql: """
                -- `state` is a JSON PrivacyState: lock preferences plus the hidden ids keyed by server URL.
                CREATE TABLE Privacy
                (
                    version INTEGER NOT NULL PRIMARY KEY,
                    state   TEXT    NOT NULL
                );
                """)
        }
        // [NUEVO] The library the Library tab reopens on. Appended, never edit v1.
        migrator.registerMigration("v3_last_library") { db in
            try db.execute(sql: "ALTER TABLE AppSettings ADD COLUMN last_library_id TEXT;")
        }
        return migrator
    }

    /// Tables created by `migrator`, for tests and diagnostics.
    static let tableNames: Set<String> = [
        "AppSettings", "ImageReaderSettings", "EpubReaderSettings", "HomeScreenFilters", "Privacy",
    ]
}
