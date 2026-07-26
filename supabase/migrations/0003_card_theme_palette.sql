----------------------------------------------------------------------
-- 0003_card_theme_palette
--
-- Widens the manifestations.theme_id check constraint for the reworked
-- card palette: `cream` is retired (it sat a few percent off the light
-- scaffold colour, so it read as no theme at all) and `blush` + `mint`
-- are added, bringing the palette to seven — one per day of the week
-- for the daily-shuffle rotation.
--
-- `cream` stays permitted so existing rows remain valid. The Dart enum
-- no longer defines it, so CardBackdropTheme.fromId('cream') falls back
-- to chocolate; per-row theme_id is not honoured by the UI today anyway
-- (see globalCardThemeIdProvider), so nothing renders differently.
----------------------------------------------------------------------

alter table public.manifestations
  drop constraint if exists manifestations_theme_id_check;

alter table public.manifestations
  add constraint manifestations_theme_id_check
  check (theme_id in (
    'chocolate',
    'blush',
    'sage',
    'mint',
    'dusk',
    'ocean',
    'terracotta',
    'cream' -- retired, retained so pre-existing rows still validate
  ));
