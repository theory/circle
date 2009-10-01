SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET client_min_messages = warning;

BEGIN;

CREATE OR REPLACE FUNCTION check_host (
    a_host  CITEXT
) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
    PERFORM TRUE FROM hosts WHERE name = a_host;
    IF NOT FOUND THEN
        INSERT INTO hosts (name) VALUES (a_host);
    END IF;
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION check_references (
    a_host    CITEXT,
    a_channel CITEXT,
    a_nicks   CITEXT[]
) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
DECLARE
    d_got_host BOOLEAN := false;
BEGIN
    IF a_channel IS NOT NULL THEN
        PERFORM TRUE FROM channels WHERE host = a_host AND name = a_channel;
        IF NOT FOUND THEN
            d_got_host := check_host(a_host);
            INSERT INTO channels (host, name) VALUES (a_host, a_channel);
        END IF;
    END IF;

    FOR i IN 1..2 LOOP
        CONTINUE WHEN a_nicks[i] IS NULL;
        PERFORM TRUE FROM nicks WHERE host = a_host AND name = a_nicks[i];
        IF NOT FOUND THEN
            IF NOT d_got_host THEN PERFORM check_host(a_host); END IF;
            INSERT INTO nicks (host, name) VALUES (a_host, a_nicks[i]);
        END IF;
    END LOOP;
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION add_event(
    a_host     CITEXT,
    a_channel  CITEXT,
    a_nick     CITEXT,
    a_event    IRC_EVENT,
    a_target   CITEXT,
    a_body     TEXT
) RETURNS BOOLEAN LANGUAGE SQL AS $$
    SELECT check_references($1, $2, ARRAY[$3, $5]);
    INSERT INTO events ( host, channel, nick, event, target, body )
    VALUES ( $1, $2, $3, $4, $5, COALESCE($6, '') )
    RETURNING TRUE;
$$;

CREATE OR REPLACE FUNCTION add_event(
    a_host     CITEXT,
    a_channel  CITEXT[],
    a_nick     CITEXT,
    a_event    IRC_EVENT,
    a_target   CITEXT,
    a_body     TEXT
) RETURNS BOOLEAN LANGUAGE SQL AS $$
    SELECT check_references($1, $2[i], ARRAY[$3, $5])
      FROM generate_series(array_lower($2, 1), array_upper($2, 1)) s(i);

    INSERT INTO events ( host, channel, nick, event, target, body )
    SELECT $1, $2[i], $3, $4, $5, COALESCE($6, '')
      FROM generate_series(array_lower($2, 1), array_upper($2, 1)) s(i)
     ORDER BY i;

    SELECT TRUE;
$$;

-- XXX Stuff to delete once the migration is finished.
DROP FUNCTION check_server(CITEXT);
DROP FUNCTION add_message(citext, citext, citext, irc_command, text);
DROP FUNCTION add_message(citext, citext[], citext, irc_command, text);
DROP FUNCTION check_references(CITEXT, CITEXT, CITEXT);

COMMIT;
