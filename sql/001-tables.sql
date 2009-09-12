BEGIN;

CREATE TYPE COMMAND AS ENUM (
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
);

CREATE TABLE servers (
    name CITEXT PRIMARY KEY
);

CREATE TABLE channels (
    name   CITEXT NOT NULL,
    server CITEXT NOT NULL REFERENCES servers(name),
    PRIMARY KEY (name, server)
);

CREATE TABLE messages (
    id       BIGSERIAL   PRIMARY KEY,
    server   CITEXT      NOT NULL,
    channel  CITEXT      NOT NULL,
    nick     TEXT        NOT NULL DEFAULT '',
    command  COMMAND     NOT NULL DEFAULT 'say',
    body     TEXT        NOT NULL DEFAULT '',
    tsv      tsvector    NOT NULL,
    sent_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_spam  BOOLEAN     NOT NULL DEFAULT FALSE,
    FOREIGN KEY (server, channel) references channels(server, name)
);

CREATE INDEX message_body_fti ON messages USING gin(tsv);

CREATE TRIGGER message_fti BEFORE INSERT OR UPDATE ON messages
FOR EACH ROW EXECUTE PROCEDURE
tsvector_update_trigger(tsv, 'pg_catalog.english', body);

COMMIT;
