locals {
  labels = { "app.kubernetes.io/name" = var.name }

  base_config = {
    PAPERLESS_DBENGINE  = "sqlite"
    PAPERLESS_TIME_ZONE = var.time_zone

    PAPERLESS_OCR_LANGUAGE     = var.ocr_language
    PAPERLESS_OCR_LANGUAGES    = var.ocr_languages
    PAPERLESS_OCR_IMAGE_DPI    = "300"
    PAPERLESS_OCR_DESKEW       = "true"
    PAPERLESS_OCR_ROTATE_PAGES = "true"

    # Inside the data claim, so a deleted original is not silently gone before the backup runs.
    PAPERLESS_EMPTY_TRASH_DIR = "/usr/src/paperless/data/trash"

    PAPERLESS_ADMIN_USER = var.admin_user
    PAPERLESS_ADMIN_MAIL = var.admin_mail
  }

  # PAPERLESS_ENABLE_FLOWER is presence-based, so an explicit false would start it.
  flower_config   = var.flower_enabled ? { PAPERLESS_ENABLE_FLOWER = "true" } : {}
  filename_config = var.filename_format == null ? {} : { PAPERLESS_FILENAME_FORMAT = var.filename_format }
}
