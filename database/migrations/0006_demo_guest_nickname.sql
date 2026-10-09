-- Preserve generated display_name and existing player/profile records.
ALTER TABLE app.players ADD COLUMN nickname text;
ALTER TABLE app.players ADD CONSTRAINT players_nickname_format CHECK (
  nickname IS NULL OR (char_length(nickname) BETWEEN 2 AND 12 AND nickname ~ '^[가-힣A-Za-z0-9_]+$')
);
CREATE UNIQUE INDEX players_nickname_unique ON app.players (lower(nickname) COLLATE "C") WHERE nickname IS NOT NULL;
