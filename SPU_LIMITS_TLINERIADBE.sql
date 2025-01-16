CREATE OR REPLACE FUNCTION dbo."SPU_LIMITS_TLINERIADBE" (
    "CODSGR1" character varying,
    "PS_CODSTATUS" integer,
    "PS_CODUSR" integer,
    "PS_WITH_LIMITS" integer  -- Parameter for limits flag (0/1)
)
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    Opened_Tran BOOLEAN;
    Error INTEGER;
    CODFILE INTEGER;
    CODRIA INTEGER;
    CRIA INTEGER;
    RATE DOUBLE PRECISION;
    SWV_Label_value varchar(30);
    SWV_error INTEGER;
BEGIN
    -- Initialize error handling variables
    SWV_error := 0;
    SWV_Label_value := 'SWL_Start_Label';

    -- Only proceed if WITH_LIMITS is 1
    IF "PS_WITH_LIMITS" = 1 THEN
        << SWL_Label >>
        LOOP
            CASE
                WHEN SWV_Label_value = 'SWL_Start_Label' THEN
                    Error := 0;

                    -- Get exchange rate for the currency conversion
                    SELECT "EXCHRATE" INTO RATE 
                    FROM "dbo"."TCDTFILEDBE" 
                    WHERE "CODSPM" = "CODSGR1"
                    AND "CODSTATUS" = "PS_CODSTATUS" 
                    AND "FLAG" = 'Y';

                    BEGIN
                        -- First, create audit records of current limits
                        INSERT INTO "dbo"."TMODCUROLDLIMDBE" (
                            "FLAG", "CODSBJ", "CODRIA", "CODFILE", "CODOC",
                            "CODTYPE", "CODTYPRIS", "CODSPM", "CODSTATUS",
                            "TB01", "TB02", "TB03", "TB04", "TB05",
                            "TB06", "TB07", "TB08", "TB09", "TB10",
                            "TB11", "TB12", "TB13", "TB14", "CODTRC",
                            "CREATEDDATE", "CREATEDBY", "LIMITS"
                        )
                        SELECT 
                            LINE."FLAG",
                            LINE."CODSBJ",
                            LINE."CODRIA",
                            CDT."CODFILE",
                            LINE."CODOC",
                            LINE."CODTYPE",
                            LINE."CODTYPRIS",
                            LINE."CODSPM",
                            RIA."CODSTATUS",
                            COALESCE(LINE."TB01", 0),
                            COALESCE(LINE."TB02", 0),
                            COALESCE(LINE."TB03", 0),
                            COALESCE(LINE."TB04", 0),
                            COALESCE(LINE."TB05", 0),
                            COALESCE(LINE."TB06", 0),
                            COALESCE(LINE."TB07", 0),
                            COALESCE(LINE."TB08", 0),
                            COALESCE(LINE."TB09", 0),
                            COALESCE(LINE."TB10", 0),
                            COALESCE(LINE."TB11", 0),
                            COALESCE(LINE."TB12", 0),
                            COALESCE(LINE."TB13", 0),
                            COALESCE(LINE."TB14", 0),
                            LINE."CODTRC",
                            NOW(),
                            "PS_CODUSR",
                            "PS_WITH_LIMITS"
                        FROM "dbo"."TCDTFILEDBE" CDT
                        INNER JOIN "dbo"."TRIADBE" RIA ON CDT."CODFILE" = RIA."CODFILE"
                        INNER JOIN "dbo"."TOCDBE" OC ON RIA."CODOC" = OC."CODOC"
                        INNER JOIN "dbo"."TLINERIADBE" LINE ON RIA."CODRIA" = LINE."CODRIA"
                        WHERE CDT."CODSTATUS" = "PS_CODSTATUS"
                        AND CDT."CODSPM" = "CODSGR1"
                        AND RIA."CODSTATUS" IN (19, 15)
                        AND RIA."FLAG" = 'Y'
                        AND OC."FLAGACTIVE" = 'Y'
                        AND RIA."CODTYPE" = 'EXT'
                        AND LINE."FLAG" = 'Y';

                        -- Handle status 25 (standard credit file)
                        IF "PS_CODSTATUS" = 25 THEN
                            -- Update limits for credit file on creation
                            UPDATE "dbo"."TLINERIADBE"
                            SET 
                                "TB01" = CAST(("TB01"/RATE) AS NUMERIC(7,2)),
                                "TB02" = CAST(("TB02"/RATE) AS NUMERIC(7,2)),
                                "TB03" = CAST(("TB03"/RATE) AS NUMERIC(7,2)),
                                "TB04" = CAST(("TB04"/RATE) AS NUMERIC(7,2)),
                                "TB05" = CAST(("TB05"/RATE) AS NUMERIC(7,2)),
                                "TB06" = CAST(("TB06"/RATE) AS NUMERIC(7,2)),
                                "TB07" = CAST(("TB07"/RATE) AS NUMERIC(7,2)),
                                "TB08" = CAST(("TB08"/RATE) AS NUMERIC(7,2)),
                                "TB09" = CAST(("TB09"/RATE) AS NUMERIC(7,2)),
                                "TB10" = CAST(("TB10"/RATE) AS NUMERIC(7,2)),
                                "TB11" = CAST(("TB11"/RATE) AS NUMERIC(7,2)),
                                "TB12" = CAST(("TB12"/RATE) AS NUMERIC(7,2)),
                                "TB13" = CAST(("TB13"/RATE) AS NUMERIC(7,2)),
                                "TB14" = CAST(("TB14"/RATE) AS NUMERIC(7,2))
                            FROM "dbo"."TRIADBE" RIA, "dbo"."TCDTFILEDBE" CDT
                            WHERE "dbo"."TLINERIADBE"."CODRIA" = RIA."CODRIA"
                            AND RIA."CODFILE" = CDT."CODFILE"
                            AND CDT."CODSPM" = "CODSGR1"
                            AND CDT."CODSTATUS" = 25
                            AND RIA."CODSTATUS" IN (19, 15)
                            AND CDT."FLAG" = 'Y'
                            AND RIA."FLAG" = 'Y'
                            AND "dbo"."TLINERIADBE"."FLAG" = 'Y';

                            -- Insert into modification log for status 25
                            INSERT INTO "dbo"."TMODCURLOGDBE" (
                                "CODFILE", "CODSPM", "CF_LEVEL", "CODRIA",
                                "OLDCUR", "NEWCUR", "EXCHRATE", "CODSTATUS",
                                "CREATEDDATE", "CREATEDBY", "LIMITS"
                            )
                            SELECT DISTINCT
                                CDT."CODFILE",
                                "CODSGR1",
                                'LE',
                                RIA."CODRIA",
                                CDT."CODCUR",
                                NULL, -- New currency will be updated by main procedure
                                RATE,
                                25,
                                NOW(),
                                "PS_CODUSR",
                                "PS_WITH_LIMITS"
                            FROM "dbo"."TCDTFILEDBE" CDT
                            JOIN "dbo"."TRIADBE" RIA ON CDT."CODFILE" = RIA."CODFILE"
                            WHERE CDT."CODSPM" = "CODSGR1"
                            AND CDT."CODSTATUS" = 25
                            AND CDT."FLAG" = 'Y'
                            AND RIA."CODSTATUS" IN (19, 15)
                            AND RIA."FLAG" = 'Y';
                        END IF;

                        -- Handle status 26 (active credit file)
                        IF "PS_CODSTATUS" = 26 THEN
                            -- Get the credit file code
                            SELECT "CODFILE" INTO CODFILE
                            FROM "dbo"."TCDTFILEDBE"
                            WHERE "CODSPM" = "CODSGR1"
                            AND "CODSTATUS" = "PS_CODSTATUS"
                            AND "FLAG" = 'Y';

                            -- Process each RIA code
                            FOR CRIA IN 
                                SELECT DISTINCT "CODRIA"
                                FROM "dbo"."TRIADBE"
                                WHERE "CODFILE" = CODFILE
                                AND "CODSTATUS" IN (19, 15)
                                AND "FLAG" = 'Y'
                            LOOP
                                -- Update limits for each RIA
                                UPDATE "dbo"."TLINERIADBE"
                                SET 
                                    "TB01" = CAST(("TB01"/RATE) AS NUMERIC(7,2)),
                                    "TB02" = CAST(("TB02"/RATE) AS NUMERIC(7,2)),
                                    "TB03" = CAST(("TB03"/RATE) AS NUMERIC(7,2)),
                                    "TB04" = CAST(("TB04"/RATE) AS NUMERIC(7,2)),
                                    "TB05" = CAST(("TB05"/RATE) AS NUMERIC(7,2)),
                                    "TB06" = CAST(("TB06"/RATE) AS NUMERIC(7,2)),
                                    "TB07" = CAST(("TB07"/RATE) AS NUMERIC(7,2)),
                                    "TB08" = CAST(("TB08"/RATE) AS NUMERIC(7,2)),
                                    "TB09" = CAST(("TB09"/RATE) AS NUMERIC(7,2)),
                                    "TB10" = CAST(("TB10"/RATE) AS NUMERIC(7,2)),
                                    "TB11" = CAST(("TB11"/RATE) AS NUMERIC(7,2)),
                                    "TB12" = CAST(("TB12"/RATE) AS NUMERIC(7,2)),
                                    "TB13" = CAST(("TB13"/RATE) AS NUMERIC(7,2)),
                                    "TB14" = CAST(("TB14"/RATE) AS NUMERIC(7,2))
                                WHERE "CODRIA" = CRIA
                                AND "FLAG" = 'Y';

                                -- Insert into modification log for each RIA
                                INSERT INTO "dbo"."TMODCURLOGDBE" (
                                    "CODFILE", "CODSPM", "CF_LEVEL", "CODRIA",
                                    "OLDCUR", "NEWCUR", "EXCHRATE", "CODSTATUS",
                                    "CREATEDDATE", "CREATEDBY", "LIMITS"
                                )
                                SELECT 
                                    CODFILE,
                                    "CODSGR1",
                                    'SGR',
                                    CRIA,
                                    CDT."CODCUR",
                                    NULL, -- New currency will be updated by main procedure
                                    RATE,
                                    26,
                                    NOW(),
                                    "PS_CODUSR",
                                    "PS_WITH_LIMITS"
                                FROM "dbo"."TCDTFILEDBE" CDT
                                WHERE CDT."CODFILE" = CODFILE
                                AND CDT."FLAG" = 'Y'
                                LIMIT 1;
                            END LOOP;
                        END IF;

                        EXCEPTION
                            WHEN OTHERS THEN
                                SWV_error := -1;
                                RAISE NOTICE '%', SQLERRM;
                    END;

                    Error := SWV_error;
                    SWV_error := 0;

                    IF Error <> 0 THEN
                        SWV_Label_value := 'GTRAN';
                        CONTINUE SWL_Label;
                    END IF;

                WHEN SWV_Label_value = 'GTRAN' THEN
                    IF NOT Opened_Tran THEN
                        IF SWV_error = 0 THEN
                            COMMIT;
                        ELSE
                            ROLLBACK;
                        END IF;
                    END IF;
                    SWV_error := 0;
            END CASE;
            EXIT SWL_Label;
        END LOOP;
    ELSE
        -- When PS_WITH_LIMITS = 0, just log the modification without updating limits
        -- Get the credit file code first
        SELECT "CODFILE" INTO CODFILE
        FROM "dbo"."TCDTFILEDBE"
        WHERE "CODSPM" = "CODSGR1"
        AND "CODSTATUS" = "PS_CODSTATUS"
        AND "FLAG" = 'Y';

        -- Insert log entry for currency change without limits
        INSERT INTO "dbo"."TMODCURLOGDBE" (
            "CODFILE", "CODSPM", "CF_LEVEL", "CODRIA",
            "OLDCUR", "NEWCUR", "EXCHRATE", "CODSTATUS",
            "CREATEDDATE", "CREATEDBY", "LIMITS"
        )
        SELECT 
            CODFILE,
            "CODSGR1",
            CASE 
                WHEN "PS_CODSTATUS" = 25 THEN 'LE'
                WHEN "PS_CODSTATUS" = 26 THEN 'SGR'
            END,
            NULL,
            CDT."CODCUR",
            NULL, -- New currency will be updated by main procedure
            NULL, -- No exchange rate when limits = 0
            "PS_CODSTATUS",
            NOW(),
            "PS_CODUSR",
            "PS_WITH_LIMITS"
        FROM "dbo"."TCDTFILEDBE" CDT
        WHERE CDT."CODFILE" = CODFILE
        AND CDT."FLAG" = 'Y'
        LIMIT 1;
    END IF;

    RETURN;
END;
$function$;
