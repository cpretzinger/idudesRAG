 - SocialAssets/
      - brand/
      - logo_primary.svg
      - logo_icon.svg
      - palette.json (hex values, gradients)
      - fonts/ (optional; store license-safe files)
  - overlays/
      - instagram/
        - ig_overlay_hook_v1.png
        - ig_lower_third_v1.png
      - facebook/
        - fb_overlay_hook_v1.png
      - linkedin/
        - li_overlay_banner_v1.png
  - templates/
      - reels/
        - reel_frame_v1.png
      - posts/
        - post_frame_square_v1.png
  - thumbnails/
      - base/
        - thumb_base_v1.png
      - exported/ (optional; where n8n writes finished thumbs)
  - music/ (optional)
      - short_intro_theme_v1.mp3
  - manifest/
      - assets-manifest.json

  Notes

  - Use transparent PNGs for overlays; prefer SVG for logos/brand marks.
  - Keep filenames descriptive and versioned (…_v1.png). Don’t rename files; replace in-place to keep fileId
  stable.
  - Capture folder IDs (SocialAssets + each subfolder) for quick lookups in n8n, or rely on a manifest.

  Optional manifest (recommended)

  - Path: SocialAssets/manifest/assets-manifest.json
  - Contents (example):

  {
  "logo.primary": "1AbcDEF_logoPrimarySvgFileId",
  "overlay.ig.hook": "1XyZ_igOverlayHookPngFileId",
  "overlay.fb.hook": "1Qwe_fbOverlayHookPngFileId",
  "template.reel.frame": "1Rst_reelFramePngFileId",
  "thumbnail.base": "1UvW_thumbBasePngFileId"
  }
