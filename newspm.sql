CREATE OR REPLACE FUNCTION dbo."SPU_TSPMCURDBE" (
    "PS_CODSPM" character varying,
    "PS_NEWCUR" character varying,
    "PS_RATMDF" numeric,
    "PS_CODUSR" integer,
    "PS_COMCUR" text,
    "PS_CF_LEVEL" character varying,
    "PS_CODSTATUS" integer,
    "limits" integer  -- New parameter for limits
)
RETURNS void
LANGUAGE plpgsql AS $function$
DECLARE
    OLDCUR VARCHAR(3);
    CODFILE NUMERIC(7,0);
    CODRIA int;
    CODOC VARCHAR(10);
    CODCOM NUMERIC(8,0);
    CRARRAY int [];
    CRIA int;
    EXCHRATE DOUBLE PRECISION;
BEGIN
    -- Check if the record exists in TSPMDBE
    IF EXISTS (SELECT 1 FROM "dbo"."TSPMDBE" WHERE "CODSPM" = "PS_CODSPM" AND "CODLEVEL" = "PS_CF_LEVEL" AND "FLAG" = 'Y') THEN
        -- Get the old currency
        SELECT "CODCUR" INTO OLDCUR 
        FROM "dbo"."TSPMDBE" 
        WHERE "CODSPM" = "PS_CODSPM" AND "CODLEVEL" = "PS_CF_LEVEL" AND "FLAG" = 'Y';

        -- Update the currency
        UPDATE "dbo"."TSPMDBE"
        SET "CODCUR" = "PS_NEWCUR"
        WHERE "CODSPM" = "PS_CODSPM" AND "CODLEVEL" = "PS_CF_LEVEL" AND "FLAG" = 'Y';

        -- If the CF_LEVEL is 'SGR', update the related records
        IF "PS_CF_LEVEL" = 'SGR' THEN
            UPDATE "dbo"."TSPMDBE"
            SET "CODCUR" = "PS_NEWCUR"
            WHERE "CODSPM1" = "PS_CODSPM" AND "CODLEVEL" = 'LE' AND "FLAG" = 'Y';
        END IF;

        -- Update based on CODSTATUS 25 or 26 allowed
        UPDATE "dbo"."TCDTFILEDBE"
        SET "CODCUR" = "PS_NEWCUR"
        WHERE "CODSPM" = "PS_CODSPM" AND "CODSTATUS" IN ("PS_CODSTATUS") AND "FLAG" = 'Y';
    END IF;

    -- Calculate the exchange rate
    EXCHRATE := (
        (SELECT "EXCHRATE" FROM "dbo"."TEXCHANGERATEDBE" WHERE "CODCUR" = OLDCUR AND "MESCODCUR" = 'EUR') /
        (SELECT "EXCHRATE" FROM "dbo"."TEXCHANGERATEDBE" WHERE "CODCUR" = "PS_NEWCUR" AND "MESCODCUR" = 'EUR')
    );

    -- Update the EQTY based on the exchange rate
    UPDATE "dbo"."TSPMDBE"
    SET "EQTY" = "EQTY" / EXCHRATE, "DATVALEQTY" = NOW()
    WHERE "CODSPM" = "PS_CODSPM" AND "CODLEVEL" = "PS_CF_LEVEL" AND "FLAG" = 'Y';

    IF "PS_CF_LEVEL" = 'SGR' THEN
        UPDATE "dbo"."TSPMDBE"
        SET "EQTY" = "EQTY" / EXCHRATE
        WHERE "CODSPM1" = "PS_CODSPM" AND "CODLEVEL" = 'LE' AND "FLAG" = 'Y';
    END IF;

    -- Insert into TMODCURLOGDBE with limits
    INSERT INTO "dbo"."TMODCURLOGDBE" (
        "CODFILE", "CODSPM", "CF_LEVEL", "CODRIA", "OLDCUR", "NEWCUR", 
        "EXCHRATE", "CODSTATUS", "CREATEDDATE", "CREATEDBY", "limits"
    )
    VALUES (
        CODFILE, "PS_CODSPM", "PS_CF_LEVEL", CRARRAY, OLDCUR, "PS_NEWCUR", 
        CASE WHEN limits = 0 THEN NULL ELSE EXCHRATE END, 
        "PS_CODSTATUS", NOW(), "PS_CODUSR", limits
    );

    -- Check if there are records in TCDTFILEDBE
    IF EXISTS (SELECT 1 FROM "dbo"."TCDTFILEDBE" WHERE "CODSPM" = "PS_CODSPM" AND "COD STATUS" = "PS_CODSTATUS" AND "FLAG" = 'Y') THEN
        -- Get the CODFILE based on CODSPM
        SELECT "CODFILE" INTO CODFILE 
        FROM "dbo"."TCDTFILEDBE" 
        WHERE "CODSPM" = "PS_CODSPM" AND "CODSTATUS" = "PS_CODSTATUS" AND "FLAG" = 'Y';

        -- If CODSTATUS is 26, process related CODRIA records
        IF "PS_CODSTATUS" = 26 THEN
            FOR CRIA IN SELECT "CODRIA" FROM "dbo"."TRIADBE" WHERE "CODFILE" = CODFILE AND "CODSTATUS" IN (19, 15) AND "FLAG" = 'Y' GROUP BY "CODRIA" LOOP
                -- Insert into comments table
                INSERT INTO "dbo"."TCOMMENTDBE" ("FLAG", "CODCOM", "CODUSER", "CODTYPE", "CODOC", "CODRIA", "DATCOM", "FLAGNOTIF") 
                VALUES ('Y', CODCOM, "PS_CODUSR", 'EXT', '3000315058', CRIA, LOCALTIMESTAMP, 'N');

                -- Update the comment
                UPDATE "dbo"."TCOMMENTDBE" 
                SET "COMMENT" = convert_from(decode("PS_COMCUR", 'base64'), 'UTF8') 
                WHERE "CODOC" = '3000315058' AND "CODRIA" = CRIA AND "CODCOM" = CODCOM;
            END LOOP;
        END IF;

        -- Insert into TMODCURLOGDBE for audit
        INSERT INTO "dbo"."TMODCURLOGDBE" (
            "CODFILE", "CODSPM", "CF_LEVEL", "CODRIA", "OLDCUR", "NEWCUR", 
            "EXCHRATE", "CODSTATUS", "CREATEDDATE", "CREATEDBY", "limits"
        )
        VALUES (
            CODFILE, "PS_CODSPM", "PS_CF_LEVEL", CRARRAY, OLDCUR, "PS_NEWCUR", 
            CASE WHEN limits = 0 THEN NULL ELSE EXCHRATE END, 
            "PS_CODSTATUS", NOW(), "PS_CODUSR", limits
        );
    END IF;

    RETURN;
END;
$function$;
