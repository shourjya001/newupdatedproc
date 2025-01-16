CREATE OR REPLACE FUNCTION dbo."SPU_LIMITS_TLINERIADBE" (
    "CODSGR1" character varying,
    "PS_CODSTATUS" integer,
    "PS_CODUSR" integer,
    "limits" integer  -- New parameter for limits
)
RETURNS void
LANGUAGE plpgsql AS $function$
DECLARE
    SWV_error INTEGER := 0;
    SWV_Label_value varchar(30) := 'SWL_Start_Label';
    RATE DOUBLE PRECISION;
    CODFILE INTEGER;
    CODRIA INTEGER;
    CRIA INTEGER;
BEGIN
    <<SWL_Label>>
    LOOP
        CASE
            WHEN SWV_Label_value = 'SWL_Start_Label' THEN
                -- Initialize error
                SWV_error := 0;

                -- Get the exchange rate
                SELECT "EXCHRATE" INTO RATE 
                FROM "dbo"."TCDTFILEDBE" 
                WHERE "CODSPM" = "CODSGR1" 
                  AND "CODSTATUS" = "PS_CODSTATUS" 
                  AND "FLAG" = 'Y';

                -- Insert into TMODCUROLDLIMDBE
                INSERT INTO "dbo"."TMODCUROLDLIMDBE" (
                    "FLAG", "CODSBJ", "CODRIA", "CODFILE", "CODOC", 
                    "CODTYPE", "CODTYPRIS", "CODSPM", "CODSTATUS", 
                    "TB01", "TB02", "TB03", "TB04", "TB05", 
                    "TB06", "TB07", "TB08", "TB09", "TB10", 
                    "T611", "T812", "TB13", "TB14", "TRC", 
                    "CREATEDDATE", "CREATEDBY"
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
                    COALESCE(LINE."T611", 0),
                    COALESCE(LINE."T812", 0),
                    COALESCE(LINE."TB13", 0),
                    COALESCE(LINE."TB14", 0),
                    LINE."CODTRC", 
                    NOW(), 
                    "PS_CODUSR"
                FROM "TCDTFILEDBE" CDT
                JOIN "TRIADBE" RIA ON CDT."CODFILE" = RIA."CODFILE"
                JOIN "TOCDBE" OC ON RIA."CODOC" = OC."CODOC"
                JOIN "TLINERIADBE" LINE ON RIA."CODRIA" = LINE."CODRIA" 
                    AND RIA."CODTYPE" = LINE."CODTYPE"
                    AND RIA."CODOC" = LINE."CODOC"
                WHERE CDT."CODSTATUS" = "PS_CODSTATUS"
                  AND CDT."CODSPM" = "CODSGR1"
                  AND RIA."CODSTATUS" IN (19, 15)
                  AND RIA."FLAG" = 'Y'
                  AND OC."FLAGACTIVE" = 'Y'
                  AND LINE."FLAG" = 'Y';

                -- Update based on CODSTATUS
                IF "PS_CODSTATUS" = 25 THEN
                    UPDATE "dbo"."TLINERIADBE" 
                    SET
                        "TB01" = CAST(("TB01" / RATE) AS NUMERIC(7, 2)),
                        "TB02" = CAST(("TB02" / RATE) AS NUMERIC(7, 2)),
                        "TB03" = CAST(("TB03" / RATE) AS NUMERIC(7, 2)),
                        "TB04" = CAST(("TB04" / RATE) AS NUMERIC(7, 2)),
                        "TB05" = CAST(("TB05" / RATE) AS NUMERIC( 7, 2)),
                        "TB06" = CAST(("TB06" / RATE) AS NUMERIC(7, 2)),
                        "TB07" = CAST(("TB07" / RATE) AS NUMERIC(7, 2)),
                        "TB08" = CAST(("TB08" / RATE) AS NUMERIC(7, 2)),
                        "TB09" = CAST(("TB09" / RATE) AS NUMERIC(7, 2)),
                        "TB10" = CAST(("TB10" / RATE) AS NUMERIC(7, 2)),
                        "T611" = CAST(("T611" / RATE) AS NUMERIC(7, 2)),
                        "T812" = CAST(("T812" / RATE) AS NUMERIC(7, 2)),
                        "TB13" = CAST(("TB13" / RATE) AS NUMERIC(7, 2)),
                        "TB14" = CAST(("TB14" / RATE) AS NUMERIC(7, 2))
                    WHERE "CODSPM" = "CODSGR1" 
                      AND "CODSTATUS" = "PS_CODSTATUS" 
                      AND "FLAG" = 'Y';
                END IF;

                -- Insert into TMODCUROLDLIMDBE for audit
                INSERT INTO "dbo"."TMODCUROLDLIMDBE" (
                    "CODSBJ", "CODRIA", "CODFILE", "CODOC", 
                    "CODTYPE", "CODSPM", "CODSTATUS", 
                    "CREATEDDATE", "CREATEDBY", "limits"
                )
                VALUES (
                    "CODSGR1", CODRIA, CODFILE, '3000315058', 
                    'EXT', "CODSGR1", "PS_CODSTATUS", 
                    NOW(), "PS_CODUSR", limits
                );

                -- Exit the loop
                EXIT SWL_Label;
        END CASE;
    END LOOP;

    RETURN;
END;
$function$;
