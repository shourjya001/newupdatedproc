-- Second procedure: SPU_TSPMCURDBE
CREATE OR REPLACE FUNCTION dbo."SPU_TSPMCURDBE" (
    "PS_CODSPM" character varying,
    "PS_NEWCUR" character varying,
    "PS_RATMDF" numeric,
    "PS_CODUSR" integer,
    "PS_COMCUR" text,
    "PS_CF_LEVEL" character varying,
    "PS_CODSTATUS" integer,
    "PS_WITH_LIMITS" integer
)
RETURNS void
LANGUAGE plpgsql AS $function$
DECLARE
    OLDCUR VARCHAR(3);
    CODFILE NUMERIC(7,0);
    CODRIA int;
    CODOC VARCHAR(10);
    CODCOM NUMERIC(8,0);
    CRARRAY int[];
    CRIA int;
    EXCHRATE DOUBLE PRECISION;
BEGIN
    -- Check if record exists
    IF EXISTS(SELECT FROM "dbo"."TSPMDBE" 
              WHERE "CODSPM" = "PS_CODSPM" 
              AND "CODLEVEL" = "PS_CF_LEVEL" 
              AND "FLAG" = 'Y') THEN
        
        -- Get old currency
        SELECT "CODCUR" INTO OLDCUR 
        FROM "dbo"."TSPMDBE" 
        WHERE "CODSPM" = "PS_CODSPM"
        AND "CODLEVEL" = "PS_CF_LEVEL"
        AND "FLAG" = 'Y';

        -- Update currency in TSPMDBE - This happens regardless of WITH_LIMITS
        UPDATE "dbo"."TSPMDBE"
        SET "CODCUR" = "PS_NEWCUR"
        WHERE "CODSPM" = "PS_CODSPM"
        AND "CODLEVEL" = "PS_CF_LEVEL"
        AND "FLAG" = 'Y';

        -- Calculate exchange rate only if WITH_LIMITS = 1
        IF "PS_WITH_LIMITS" = 1 THEN
            EXCHRATE := ((SELECT "EXCHRATE" 
                         FROM "dbo"."TEXCHANGERATEDBE" 
                         WHERE "CODCUR" = OLDCUR AND "MESCODCUR" = 'EUR') /
                        (SELECT "EXCHRATE" 
                         FROM "dbo"."TEXCHANGERATEDBE" 
                         WHERE "CODCUR" = "PS_NEWCUR" AND "MESCODCUR" = 'EUR'));
            
            -- Update quantities only if WITH_LIMITS = 1
            UPDATE "dbo"."TSPMDBE"
            SET "EQTY" = "EQTY"/EXCHRATE,
                "DATVALEQTY" = now()
            WHERE "CODSPM" = "PS_CODSPM"
            AND "CODLEVEL" = "PS_CF_LEVEL"
            AND "FLAG" = 'Y';
        END IF;

        -- Insert audit record with conditional EXCHRATE
        INSERT INTO "dbo"."TCURAUDDBE" (
            "CODSPM", "CF_LEVEL", "NEWCUR", "DATMOD", "OLDCUR", 
            "EXCHRATE", "CODUSR", "COMMENT", "LIMITS"
        )
        VALUES (
            "PS_CODSPM", 
            "PS_CF_LEVEL", 
            "PS_NEWCUR", 
            LOCALTIMESTAMP, 
            OLDCUR,
            CASE WHEN "PS_WITH_LIMITS" = 1 THEN EXCHRATE ELSE NULL END,
            "PS_CODUSR", 
            "PS_COMCUR",
            "PS_WITH_LIMITS"
        );

        -- Handle credit file updates
        IF EXISTS(SELECT FROM "dbo"."TCDTFILEDBE" 
                 WHERE "CODSPM" = "PS_CODSPM" 
                 AND "CODSTATUS" = "PS_CODSTATUS" 
                 AND "FLAG" = 'Y') THEN
            
            SELECT "CODFILE" INTO CODFILE 
            FROM "dbo"."TCDTFILEDBE" 
            WHERE "CODSPM" = "PS_CODSPM"
            AND "CODSTATUS" = "PS_CODSTATUS"
            AND "FLAG" = 'Y';

            -- Insert modification log entry
            INSERT INTO "dbo"."TMODCURLOGDBE" (
                "CODFILE", "CODSPM", "CF_LEVEL", "CODRIA",
                "OLDCUR", "NEWCUR", "EXCHRATE", "CODSTATUS",
                "CREATEDDATE", "CREATEDBY", "LIMITS"
            )
            VALUES (
                CODFILE, 
                "PS_CODSPM", 
                "PS_CF_LEVEL", 
                CASE WHEN "PS_CODSTATUS" = 25 THEN CODFILE ELSE NULL END,
                OLDCUR, 
                "PS_NEWCUR",
                CASE WHEN "PS_WITH_LIMITS" = 1 THEN EXCHRATE ELSE NULL END,
                "PS_CODSTATUS", 
                NOW(), 
                "PS_CODUSR",
                "PS_WITH_LIMITS"
            );
        END IF;
    END IF;

    RETURN;
END;
$function$;
