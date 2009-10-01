SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET client_min_messages = warning;

BEGIN;

CREATE TYPE IRC_EVENT AS ENUM (
    'admin',      -- Unimplemented: 256-259, 423
    'away',
    'back',
    'chan_mode',
    'cnotice',    -- Unimplemented: 441
    'connect',
    'disconnect',
    'emote',
    'error',
    'gline',      -- Unimplemented: 280-281
    'helpop',     -- Unimplemented: 290-294
    'info',       -- Unimplemented: 371/374
    'invite',
    'ison',
    'join',
    'kick',
    'kill',       -- Unimplemented: 483-484
    'links',      -- Unimplemented: 364/365
    'list',       -- Unimplemented: 321-323
    'lusers',     -- Unimplemented: 251-255, 265-266
    'map',        -- Unimplemented: 005
    'motd',       -- Unimplemented: 375, 372, 376
    'names',
    'nick',
    'nooper',     -- Unimplemented: 491
    'notice',
    'nouser',     -- Unimplemented: 441
    'oper',       -- Unimplemented: 381
    'part',
    'ping',       -- Not logged
    'private',
    'public',
    'quit',
    'rehash',     -- Unimplemented: 382
    'shutdown',
    'silence',    -- Unimplemented: 271-272, 511
    'stats',      -- Unimplemented: 211-219, 222-224, 241-244, 247-250
    'summon',     -- Unimplemented: 342; 445 (not in use)
    'time',       -- Not logged
    'topic',
    'unwatch',    -- Unimplemented: 602
    'user_mode',
    'userhost',   -- Unimplemented: 302
    'userip',     -- Unimplemented: 307/240
    'users',      -- Unimplemented: 392-395; 446 (not in use)
    'version',    -- Unimplemented: 351
    'watch',      -- Unimplemented: 604, 605
    'watchlist',  -- Unimplemented: 603, 606
    'who',        -- Unimplemented: 315, 352, 416
    'whois',
    'whowas'
);

COMMENT ON TYPE IRC_EVENT IS
'Taken from mIRC: (http://www.mirc.net/raws/) and RFC 1459 section 6.2 (http://www.faqs.org/rfcs/rfc1459.html)';

-- XXX Stuff to delete once the migration is finished.
ALTER TABLE servers  RENAME TO hosts;
ALTER TABLE channels RENAME server TO host;
ALTER TABLE nicks    RENAME server TO host;

CREATE TABLE events (
    id       BIGSERIAL   PRIMARY KEY,
    host     CITEXT      NOT NULL,
    channel  CITEXT          NULL,
    nick     CITEXT      NOT NULL,
    event    IRC_EVENT   NOT NULL DEFAULT 'public',
    body     TEXT        NOT NULL DEFAULT '',
    target   CITEXT          NULL,
    tsv      tsvector    NOT NULL,
    seen_at  TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    is_spam  BOOLEAN     NOT NULL DEFAULT FALSE,
    FOREIGN KEY (channel, host) REFERENCES channels(name, host)
            ON DELETE CASCADE  ON UPDATE CASCADE,
    FOREIGN KEY (nick, host)    REFERENCES nicks(name, host)
            ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (target, host)  REFERENCES nicks(name, host)
            ON DELETE RESTRICT ON UPDATE CASCADE
);


-- XXX Stuff to delete once the migration is finished.
INSERT INTO events (host, channel, nick, event, body, tsv, seen_at, is_spam)
SELECT server, channel, nick,
       CASE command WHEN 'say' THEN 'public' ELSE command::text::irc_event END,
       body, tsv, seen_at, is_spam
  FROM messages;

DROP TABLE messages;

CREATE INDEX event_body_fti    ON events USING gin(tsv);
CREATE INDEX event_seen_at_idx ON events(seen_at);
CREATE INDEX event_host_fdx    ON events(host);
CREATE INDEX event_event_idx   ON events(event);
CREATE INDEX event_nick_fdx    ON events(nick, host);
CREATE INDEX event_channel_fdx ON events(channel, host) WHERE channel IS NOT NULL;
CREATE INDEX event_target_fdx  ON events(target, host)  WHERE target  IS NOT NULL;

CREATE TRIGGER event_fti BEFORE INSERT OR UPDATE ON events
FOR EACH ROW EXECUTE PROCEDURE
tsvector_update_trigger(tsv, 'pg_catalog.english', body);

COMMIT;

-- XXX Stuff to delete once the migration is finished.
VACUUM FULL;
VACUUM;
ANALYZE;
