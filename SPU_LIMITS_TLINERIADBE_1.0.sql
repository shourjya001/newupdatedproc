-- Second procedure: SPU_LIMITS_TLINERIADBE
CREATE OR REPLACE FUNCTION dbo."SPU_LIMITS_TLINERIADBE" (
    "CODSGR1" character varying,
    "PS_CODSTATUS" integer,
    "PS_CODUSR" integer,
    "PS_WITHLIMIT" integer  -- New parameter
)
RETURNS void
LANGUAGE plpgsql AS $function$
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
    IF "PS_WITHLIMIT" = 0 THEN
        RETURN;  -- Exit if no limits processing needed
    END IF;

    SWV_error := 0;
    SWV_Label_value := 'SWL_Start_Label';

    << SWL_Label >>
    LOOP
        CASE
            WHEN SWV_Label_value = 'SWL_Start_Label' THEN
                Error := 0;
                
                select "EXCHRATE" INTO RATE 
                from "dbo"."TCDTFILEDBE" 
                WHERE "CODSPM" = "CODSGR1"
                AND "CODSTATUS" = "PS_CODSTATUS" 
                AND "FLAG" = 'Y';

                begin
                    insert into "dbo"."TMODCUROLDLIMDBE"
                    ("FLAG", "CODSBJ", "CODRIA", "CODFILE", "CODOC", 
                     "CODTYPE", "CODTYPRIS", "CODSPM", "CODSTATUS",
                     "TB01", "TB02", "TB03", "TB04", "TB05", "TB06", "TB07", 
                     "TB08", "TB09", "TB10", "TB11", "TB12", "TB13", "TB14", 
                     "CODTRC", "CREATEDDATE", "CREATEDBY")
                    select 
                        LINE."FLAG",
                        LINE."CODSBJ",
                        LINE."CODRIA",
                        CDT."CODFILE",
                        LINE."CODOC",
                        LINE."CODTYPE",
                        LINE."CODTYPRIS",
                        LINE."CODSPM",
                        RIA."CODSTATUS",
                        COALESCE(LINE."TB01",0),
                        COALESCE(LINE."TB02",0),
                        COALESCE(LINE."TB03",0),
                        COALESCE(LINE."TB04",0),
                        COALESCE(LINE."TB05",0),
                        COALESCE(LINE."TB06",0),
                        COALESCE(LINE."TB07",0),
                        COALESCE(LINE."TB08",0),
                        COALESCE(LINE."TB09",0),
                        COALESCE(LINE."TB10",0),
                        COALESCE(LINE."TB11",0),
                        COALESCE(LINE."TB12",0),
                        COALESCE(LINE."TB13",0),
                        COALESCE(LINE."TB14",0),
                        LINE."CODTRC",
                        NOW(),
                        "PS_CODUSR"
                    from "TCDTFILEDBE" CDT, "TRIADBE" RIA, 
                         "TOCDBE" OC, "TLINERIADBE" LINE
                    where CDT."CODFILE" = RIA."CODFILE"
                    AND CDT."CODSTATUS" = "PS_CODSTATUS"
                    AND CDT."CODSPM" = "CODSGR1"
                    AND RIA."CODSTATUS" in (19,15)
                    AND RIA."FLAG" = 'Y'
                    AND RIA."CODOC" = OC."CODOC"
                    AND OC."FLAGACTIVE" = 'Y'
                    AND RIA."CODTYPE" = 'EXT'
                    AND RIA."CODRIA" = LINE."CODRIA"
                    AND RIA."CODTYPE" = LINE."CODTYPE"
                    AND RIA."CODOC" = LINE."CODOC"
                    AND LINE."FLAG" = 'Y';

                    -- Rest of your existing TB update logic
                    if("PS_CODSTATUS" = 25) then
                        UPDATE "dbo"."TLINERIADBE" SET
                            "TB01" = CAST(("TB01"/RATE) AS NUMERIC(7,2)),
                            "TB02" = CAST(("TB02"/RATE) AS NUMERIC(7,2)),
                            -- ... (rest of TB updates)
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
                        FROM "dbo"."TRIADBE" "RIA", "dbo"."TCDTFILEDBE" "CDT"
                        WHERE "dbo"."TLINERIADBE"."CODRIA" = "RIA"."CODRIA"
                        AND "RIA"."CODFILE" = "CDT"."CODFILE"
                        AND "CDT"."CODSPM" = "CODSGR1"
                        AND "CDT"."CODSTATUS" = 25
                        AND "CDT"."FLAG" = 'Y';
                    end if;

                    -- Update TMODCURLOGDBE to set LIMITS = 1
                    UPDATE "dbo"."TMODCURLOGDBE"
                    SET "LIMITS" = 1
                    WHERE "CODSPM" = "CODSGR1"
                    AND "CODSTATUS" = "PS_CODSTATUS"
                    AND "CREATEDDATE" = (
                        SELECT MAX("CREATEDDATE")
                        FROM "dbo"."TMODCURLOGDBE"
                        WHERE "CODSPM" = "CODSGR1"
                        AND "CODSTATUS" = "PS_CODSTATUS"
                    );

                EXCEPTION
                    WHEN OTHERS THEN
                        SWV_error := -1;
                        raise notice '%', SQLERRM;
                end;

                Error := SWV_error;
                SWV_error := 0;

                IF Error <> 0 then
                    SWV_Label_value := 'GTRAN';
                    CONTINUE SWL_Label;
                end if;

                SWV_Label_value := 'GTRAN';

            WHEN SWV_Label_value = 'GTRAN' THEN
                IF Opened_Tran = false then
                    IF SWV_error = 0 then
                        COMMIT;
                    ELSE
                        ROLLBACK;
                    end if;
                    SWV_error := 0;
                end if;
        END CASE;
        EXIT SWL_Label;
    END LOOP;

    return;
END;
$function$;
