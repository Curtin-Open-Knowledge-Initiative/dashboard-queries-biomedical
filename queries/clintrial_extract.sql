-----------------------------------------------------------------------
-- Montreal Neuro - Data extract of the academic Observatory to 
-- extract Crossref and Pubmed data and make a combined list of
-- Clinical trials
-----------------------------------------------------------------------
DECLARE var_SQL_script_name STRING DEFAULT 'clintrial_extract_ver1l_2023_09_28';

-----------------------------------------------------------------------
-- 0. EXTRACT AND TIDY FIELDS OF INTEREST
-----------------------------------------------------------------------
WITH main_select AS (
  SELECT
  ------ 0.1 DOI TABLE: Misc METADATA
  academic_observatory.doi,
  academic_observatory.crossref.published_year, -- from doi table

  ------ 0.2 CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - CROSSREF - contained in fields
  (SELECT array_agg(registry)[offset(0)]
     FROM UNNEST(academic_observatory.crossref.clinical_trial_number))
     AS CROSSREF_clintrial_fromfield_registry,

  (SELECT array_agg(type)[offset(0)]
     FROM UNNEST(academic_observatory.crossref.clinical_trial_number))
     AS CROSSREF_clintrial_fromfield_type,

  UPPER(TRIM((SELECT REPLACE(TRIM(array_agg(clinical_trial_number)[offset(0)]),'  ', ' ')
     FROM UNNEST(academic_observatory.crossref.clinical_trial_number))))
     AS CROSSREF_clintrial_fromfield_ids,

  CASE
    WHEN academic_observatory.crossref.clinical_trial_number IS NULL THEN FALSE
    WHEN ARRAY_LENGTH(academic_observatory.crossref.clinical_trial_number) > 0 THEN TRUE
    ELSE FALSE
  END as CROSSREF_clintrial_fromfield_found,
  
  ------ 0.3 CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - CROSSREF Abstract search for trial numbers
  REGEXP_EXTRACT_ALL(UPPER(academic_observatory.crossref.abstract), r'NCT0\\d{7}') 
    AS CROSSREF_clintrial_fromabstract_ids,

  CASE
    WHEN academic_observatory.crossref.abstract IS NULL THEN FALSE
    WHEN academic_observatory.crossref.abstract = "" THEN FALSE
    WHEN academic_observatory.crossref.abstract = "{}" THEN FALSE
    WHEN REGEXP_CONTAINS(UPPER(academic_observatory.crossref.abstract), r'NCT0\\d{7}') THEN TRUE
    ELSE FALSE
  END as CROSSREF_clintrial_fromabstract_found,

  ------ 0.4 ABSTRACTS from any sources
  academic_observatory.crossref.abstract AS abstract_CROSSREF,
  pubmed.pubmed_Abstract AS abstract_PUBMED,
 
  ------ 0.5 PUBMED TABLE: CONCATENATED Clinical Trial Registries/Data Banks,and Accession Numbers (optional fields)
  ------- This field is overloaded, requirin special processing!
  pubmed.pubmed_DataBankList AS pubmed_DataBankList_RAW,
  TRIM((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList))) AS PUBMED_DataBankList_names_CONCAT,
  TRIM((SELECT STRING_AGG(id, " ") FROM UNNEST(pubmed.pubmed_DataBankList))) AS PUBMED_DataBankList_ids_CONCAT,

  "" AS PUBMED_clintrial_fromabstract_ids,
  FALSE AS PUBMED_clintrial_fromabstract_found,
 -----------------------------------------------------------------------
 FROM
    ------ Crossref from Academic Observatory.
    `academic-observatory.observatory.doi20230618` as academic_observatory
    # PubMed is only included here as the required fields are not yet in the Academic Observatory
    LEFT JOIN `university-of-ottawa.neuro_data_processed.pubmed_extract` as pubmed
      ON LOWER(academic_observatory.doi) = LOWER(pubmed_doi)
      WHERE academic_observatory.crossref.published_year > 2000

 ), # END OF 0. SELECT main_select

-----------------------------------------------------------------------
-- 1 Flatten the nested Pubmed data
-----------------------------------------------------------------------
table_1 AS (
SELECT 
  doi,
  pubmed_DataBankList_unested1.name AS PUBMED_DataBankList_names,
  pubmed_DataBankList_unested1.id AS PUBMED_DataBankList_ids,
FROM
  main_select ,
  UNNEST(pubmed_DataBankList_RAW) AS pubmed_DataBankList_unested1
), # END. SELECT table_1

-----------------------------------------------------------------------
-- 2: Extract just the CLINICAL TRIAL Registries from the overloaded field
-----------------------------------------------------------------------
table_2 AS (
SELECT
  doi,
  STRING_AGG(PUBMED_DataBankList_names, ' ') AS PUBMED_clintrial_fromfield_names,
  UPPER(STRING_AGG(PUBMED_DataBankList_ids, ' ')) AS PUBMED_clintrial_fromfield_ids
  FROM table_1
    WHERE REGEXP_CONTAINS(PUBMED_DataBankList_names,'ANZCTR|ChiCTR|CRiS|ClinicalTrials\\.gov|CTRI|DRKS|EudraCT|IRCT|ISRCTN|JapicCTI|JMACCT|JPRN|NTR|PACTR|ReBec|REPEC|RPCEC|SLCTR|TCTR|UMIN CTR|UMIN-CTR')
    GROUP by doi
), # END. SELECT table_2

-----------------------------------------------------------------------
-- 3: Link CLINICAL TRIAL Registries to main query
-----------------------------------------------------------------------
table_3 AS (
SELECT
  main_select.*,
  table_2_joined.PUBMED_clintrial_fromfield_names,
  table_2_joined.PUBMED_clintrial_fromfield_ids,
  CASE
    WHEN table_2_joined.PUBMED_clintrial_fromfield_ids IS NULL THEN FALSE
    WHEN LENGTH(table_2_joined.PUBMED_clintrial_fromfield_ids) > 0 THEN TRUE
    ELSE FALSE
  END AS PUBMED_clintrial_fromfield_found

FROM main_select
  FULL JOIN table_2 as table_2_joined
  ON LOWER(main_select.doi) = LOWER(table_2_joined.doi)
), # END. SELECT table_3

-----------------------------------------------------------------------
-- 4: Combine trial IDs and registies for BOTH Crossref and Pubmed
-----------------------------------------------------------------------
table_4 AS (
  SELECT
  * EXCEPT (pubmed_DataBankList_RAW),  
  ------ 4.1 Clinical Trial - combine Trial-IDs from all sources
    TRIM(REPLACE(
        CONCAT(COALESCE(CROSSREF_clintrial_fromfield_ids,""), " ",
        # The following complex statement is to capture missing (?) values that returns "0 rows" isntead of null
        TRIM(COALESCE((SELECT CONCAT(p1) FROM UNNEST(CROSSREF_clintrial_fromabstract_ids) AS p1) ,'')),
        COALESCE(PUBMED_clintrial_fromfield_ids,""), " ", 
        COALESCE(PUBMED_clintrial_fromabstract_ids,""), " "
       ),'  ',' ')) AS ANYSOURCE_clintrials,

  ------ 4.2 Determine if ANY Clinical Trial is found from ANY source
   IF (CROSSREF_clintrial_fromfield_found 
    OR CROSSREF_clintrial_fromabstract_found
    OR PUBMED_clintrial_fromfield_found
    OR PUBMED_clintrial_fromabstract_found, 
    TRUE, FALSE) AS ANYSOURCE_clintrial_found
  
  FROM table_3
  ), # END SELECT table 4

-----------------------------------------------------------------------
-- 5: Extract just the DATABANKS from the overloaded field
-----------------------------------------------------------------------
table_5 AS (
SELECT
  doi,
  STRING_AGG(PUBMED_DataBankList_names, ' ') AS PUBMED_opendata_fromfield_names,
  STRING_AGG(PUBMED_DataBankList_ids, ' ') AS PUBMED_opendata_fromfield_ids
FROM table_1
WHERE REGEXP_CONTAINS(PUBMED_DataBankList_names,'BioProject|dbGaP|dbSNP|dbVar|Dryad|figshare|GDB|GENBANK|GEO|OMIM|PIR|PubChem-BioAssay|PubChem-Compound|PubChem-Substance|RefSeq|SRA|SWISSPROT|UniMES|UniParc|UniProtKB|UniRef|PDB|Protein')

GROUP by doi
) # END. SELECT table_5

-----------------------------------------------------------------------
-- 6: Link Pubmed Databanks to main query
-----------------------------------------------------------------------
SELECT
  ----- 6.1 Link Pubmed Databanks to main query
  table_4.*,
  table5_joined.PUBMED_opendata_fromfield_names,
  table5_joined.PUBMED_opendata_fromfield_ids,
  CASE
    WHEN table5_joined.PUBMED_opendata_fromfield_ids IS NULL THEN FALSE
    WHEN LENGTH(table5_joined.PUBMED_opendata_fromfield_ids) > 0 OR LENGTH(table5_joined.PUBMED_opendata_fromfield_names) > 0 THEN TRUE
    ELSE FALSE
  END AS PUBMED_opendata_fromfield_found,

  ----- 6.2 UTILITY - add a variable for the script version
  var_SQL_script_name

  FROM table_4
  FULL JOIN table_5 as table5_joined
  ON LOWER(table_4.doi) = LOWER(table5_joined.doi)
  
  # END.main SELECT
-----------------------------------------------------------------------
