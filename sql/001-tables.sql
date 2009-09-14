SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET client_min_messages = warning;

BEGIN;

CREATE DOMAIN COMMAND AS TEXT CHECK (
    VALUE IN (
        'away',
        'emote',
        'join',
        'kick',
        'nick',
        'part',
        'quit',
        'say',
        'topic',
        'who'
    )
);

CREATE TABLE servers (
    name CITEXT PRIMARY KEY
);

CREATE TABLE channels (
    name   CITEXT NOT NULL,
    server CITEXT NOT NULL REFERENCES servers(name),
    PRIMARY KEY (name, server)
);

CREATE TABLE nicks (
    name   CITEXT NOT NULL,
    server CITEXT NOT NULL REFERENCES servers(name),
    PRIMARY KEY (name, server)
);

CREATE TABLE messages (
    id       BIGSERIAL   PRIMARY KEY,
    server   CITEXT      NOT NULL,
    channel  CITEXT      NOT NULL,
    nick     CITEXT      NOT NULL,
    command  COMMAND     NOT NULL DEFAULT 'say',
    body     TEXT        NOT NULL DEFAULT '',
    tsv      tsvector    NOT NULL,
    seen_at  TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    is_spam  BOOLEAN     NOT NULL DEFAULT FALSE,
    FOREIGN KEY (channel, server) REFERENCES channels(name, server),
    FOREIGN KEY (nick, server)    REFERENCES nicks(name, server)
);

CREATE INDEX message_body_fti ON messages USING gin(tsv);

CREATE TRIGGER message_fti BEFORE INSERT OR UPDATE ON messages
FOR EACH ROW EXECUTE PROCEDURE
tsvector_update_trigger(tsv, 'pg_catalog.english', body);

COMMIT;
