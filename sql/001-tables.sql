SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET client_min_messages = warning;

BEGIN;

CREATE EXTENSION CITEXT;

CREATE TYPE IRC_COMMAND AS ENUM (
    'admin',
    'away',
    'back',     -- pseudo-command, back from away
    'connect',
    'emote',
    'error',
    'info',
    'invite',
    'ison',
    'join',
    'kick',
    'kill',
    'links',
    'list',
    'mode',
    'names',
    'nick',
    'notice',
    'oper',
    'part',
    'pass',
    'ping',
    'pong',
    'privmsg',
    'quit',
    'rehash',
    'restart',
    'say',      -- pseudo-command, regular message
    'server',
    'squit',
    'stats',
    'summon',
    'time',
    'topic',
    'trace',
    'user',
    'userhost',
    'users',
    'version',
    'wallops',
    'who',
    'whois',
    'whowas'
);

COMMENT ON TYPE IRC_COMMAND IS
'Taken from RFC 1459: http://www.faqs.org/rfcs/rfc1459.html';

CREATE TABLE servers (
    name CITEXT PRIMARY KEY
);

CREATE TABLE channels (
    name   CITEXT NOT NULL,
    server CITEXT NOT NULL REFERENCES servers(name)
            ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (name, server)
);

CREATE TABLE nicks (
    name   CITEXT NOT NULL,
    server CITEXT NOT NULL REFERENCES servers(name)
            ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (name, server)
);

CREATE TABLE messages (
    id       BIGSERIAL   PRIMARY KEY,
    server   CITEXT      NOT NULL,
    channel  CITEXT      NOT NULL,
    nick     CITEXT      NOT NULL,
    command  IRC_COMMAND NOT NULL DEFAULT 'say',
    body     TEXT        NOT NULL DEFAULT '',
    tsv      tsvector    NOT NULL,
    seen_at  TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    is_spam  BOOLEAN     NOT NULL DEFAULT FALSE,
    FOREIGN KEY (channel, server) REFERENCES channels(name, server)
            ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (nick, server)    REFERENCES nicks(name, server)
            ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX message_body_fti    ON messages USING gin(tsv);
CREATE INDEX message_seen_at_idx ON messages(seen_at);
CREATE INDEX message_channel_fdx ON messages(server, channel);

CREATE TRIGGER message_fti BEFORE INSERT OR UPDATE ON messages
FOR EACH ROW EXECUTE PROCEDURE
tsvector_update_trigger(tsv, 'pg_catalog.english', body);

COMMIT;
