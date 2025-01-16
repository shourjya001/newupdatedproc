-- First procedure: SPU_TSPMCURDBE
CREATE OR REPLACE FUNCTION dbo."SPU_TSPMCURDBE" (
    "PS_CODSPM" character varying,
    "PS_NEWCUR" character varying,
    "PS_RATMDF" numeric,
    "PS_CODUSR" integer,
    "PS_COMCUR" text,
    "PS_CF_LEVEL" character varying,
    "PS_CODSTATUS" integer,
    "PS_WITHLIMIT" integer  -- New parameter
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
    if exists(Select from "dbo"."TSPMDBE" where "CODSPM" = "PS_CODSPM" and "CODLEVEL" = "PS_CF_LEVEL" and "FLAG" = 'Y') then
        select "CODCUR" INTO OLDCUR from "dbo"."TSPMDBE" 
        where "CODSPM" = "PS_CODSPM"
        and "CODLEVEL" = "PS_CF_LEVEL"
        and "FLAG" = 'Y';
        
        update "dbo"."TSPMDBE"
        set "CODCUR" = "PS_NEWCUR"
        where "CODSPM" = "PS_CODSPM"
        and "CODLEVEL" = "PS_CF_LEVEL"
        and "FLAG" = 'Y';

        if "PS_CF_LEVEL" = 'SGR' then
            update "dbo"."TSPMDBE"
            set "CODCUR" = "PS_NEWCUR"
            where "CODSPM1" = "PS_CODSPM"
            and "CODLEVEL" = 'LE'
            and "FLAG" = 'Y';
        end if;

        update "dbo"."TCDTFILEDBE"
        set "CODCUR" = "PS_NEWCUR"
        where "CODSPM" = "PS_CODSPM"
        and "CODSTATUS" in("PS_CODSTATUS")
        and "FLAG" = 'Y';
    end if;

    EXCHRATE := ((SELECT "EXCHRATE" FROM "dbo"."TEXCHANGERATEDBE" 
                  WHERE "CODCUR" = OLDCUR AND "MESCODCUR" = 'EUR')/
                 (SELECT "EXCHRATE" FROM "dbo"."TEXCHANGERATEDBE" 
                  WHERE "CODCUR" = "PS_NEWCUR" AND "MESCODCUR" = 'EUR'));

    update "dbo"."TSPMDBE"
    set "EQTY" = "EQTY"/EXCHRATE,
        "DATVALEQTY" = now()
    where "CODSPM" = "PS_CODSPM"
    and "CODLEVEL" = "PS_CF_LEVEL"
    and "FLAG" = 'Y';

    if "PS_CF_LEVEL" = 'SGR' then
        update "dbo"."TSPMDBE"
        set "EQTY" = "EQTY"/EXCHRATE
        where "CODSPM1" = "PS_CODSPM"
        and "CODLEVEL" = 'LE'
        and "FLAG" = 'Y';
    end if;

    -- Modified insert to include LIMITS
    if "PS_WITHLIMIT" = 0 then
        insert INTO "dbo"."TMODCURLOGDBE"
        ("CODFILE", "CODSPM", "CF_LEVEL", "CODRIA", "OLDCUR", "NEWCUR", 
         "EXCHRATE", "CODSTATUS", "CREATEDDATE", "CREATEDBY", "LIMITS")
        values (CODFILE, "PS_CODSPM", "PS_CF_LEVEL", CRARRAY, OLDCUR, 
                "PS_NEWCUR", NULL, "PS_CODSTATUS", NOW(), "PS_CODUSR", 0);
    else
        insert INTO "dbo"."TCURAUDDBE"
        select "PS_CODSPM", "PS_CF_LEVEL", "PS_NEWCUR", LOCALTIMESTAMP, 
               OLDCUR, EXCHRATE, "PS_CODUSR", "PS_COMCUR";
               
        insert INTO "dbo"."TMODCURLOGDBE"
        ("CODFILE", "CODSPM", "CF_LEVEL", "CODRIA", "OLDCUR", "NEWCUR", 
         "EXCHRATE", "CODSTATUS", "CREATEDDATE", "CREATEDBY", "LIMITS")
        values (CODFILE, "PS_CODSPM", "PS_CF_LEVEL", CRARRAY, OLDCUR, 
                "PS_NEWCUR", EXCHRATE, "PS_CODSTATUS", NOW(), "PS_CODUSR", 1);
    end if;

    -- Rest of the existing logic remains unchanged
    if exists(Select from "dbo"."TCDTFILEDBE" 
              where "CODSPM" = "PS_CODSPM" 
              and "CODSTATUS" = "PS_CODSTATUS" 
              and "FLAG" = 'Y') then
        if ("PS_CODSTATUS" = 26) then
            FOR CRIA IN select "CODRIA" 
                        FROM "dbo"."TRIADBE" 
                        WHERE "CODFILE" = CODFILE
                        AND "CODSTATUS" in (19,15) 
                        AND "FLAG" = 'Y' 
                        group by "CODRIA"
            LOOP
                select MAX("CODCOM")+1 INTO CODCOM 
                FROM "dbo"."TCOMMENTDBE";
                
                INSERT INTO "dbo"."TCOMMENTDBE" 
                ("FLAG", "CODCOM", "CODUSER", "CODTYPE", "CODOC", "CODRIA", 
                 "DATCOM", "FLAGNOTIF")
                VALUES('Y', CODCOM, "PS_CODUSR", 'EXT', '3000315058', CRIA, 
                       LOCALTIMESTAMP, 'N');
                
                UPDATE "dbo"."TCOMMENTDBE" 
                SET "COMMENT" = convert_from(decode("PS_COMCUR", 'base64'), 'UTF8')
                WHERE "CODOC" = '3000315058';
            END LOOP;
        end if;

        if ("PS_CODSTATUS" = 25) then
            select MAX("CODCOM")+1 INTO CODCOM FROM "dbo"."TCOMMENTDBE";
            
            INSERT INTO "dbo"."TCOMMENTDBE" 
            ("FLAG", "CODCOM", "CODUSER", "CODTYPE", "CODOC", "CODRIA", 
             "DATCOM", "FLAGNOTIF")
            VALUES('Y', CODCOM, "PS_CODUSR", 'EXT', '3000315058', CODFILE, 
                   LOCALTIMESTAMP, 'N');
            
            UPDATE "dbo"."TCOMMENTDBE" 
            SET "COMMENT" = convert_from(decode("PS_COMCUR", 'base64'), 'UTF8')
            WHERE "CODOC" = '3000315058' 
            AND "CODRIA" = CODFILE 
            AND "CODCOM" = CODCOM;
        end if;
    end if;

    RETURN;
END;
$function$;
