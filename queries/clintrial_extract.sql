-----------------------------------------------------------------------
-- Montreal Neuro - Data extract of the academic Observatory to 
-- extract Crossref and Pubmed data and make a combined list of
-- Clinical trials
-----------------------------------------------------------------------
DECLARE var_SQL_script_name STRING DEFAULT 'clintrial_extract_ver1l_2023_09_22b';

-----------------------------------------------------------------------
-- 1. EXTRACT AND TIDY FIELDS OF INTEREST
-----------------------------------------------------------------------
WITH main_select AS (
  SELECT
  ------ 1.1 DOI TABLE: Misc METADATA
  academic_observatory.doi,
  academic_observatory.crossref.published_year, -- from doi table

  ------ 1.2 CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - CROSSREF - contained in fields
  (SELECT array_agg(registry)[offset(0)]
     FROM UNNEST(academic_observatory.crossref.clinical_trial_number))
     AS CROSSREF_fromfield_registry,

  (SELECT array_agg(type)[offset(0)]
     FROM UNNEST(academic_observatory.crossref.clinical_trial_number))
     AS CROSSREF_fromfield_type,

  UPPER(TRIM((SELECT REPLACE(TRIM(array_agg(clinical_trial_number)[offset(0)]),'  ', ' ')
     FROM UNNEST(academic_observatory.crossref.clinical_trial_number))))
     AS CROSSREF_fromfield_trialid,

  CASE
    WHEN ARRAY_LENGTH(academic_observatory.crossref.clinical_trial_number) > 0 
    THEN TRUE
    ELSE FALSE
  END as CROSSREF_fromfield_trialid_found,
  
  ------ 1.3 CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - CROSSREF Abstract search for trial numbers
  REGEXP_EXTRACT_ALL(UPPER(academic_observatory.crossref.abstract), r'NCT0\\d{7}') 
    AS CROSSREF_fromabstract_trialid,

  CASE
    WHEN academic_observatory.crossref.abstract IS NULL THEN FALSE
    WHEN academic_observatory.crossref.abstract = "" THEN FALSE
    WHEN academic_observatory.crossref.abstract = "{}" THEN FALSE
    WHEN REGEXP_CONTAINS(UPPER(academic_observatory.crossref.abstract), r'NCT0\\d{7}') THEN TRUE
    ELSE FALSE
  END as CROSSREF_fromabstract_trialid_found,

  ------ 1.4 ABSTRACTS from any sources
  academic_observatory.crossref.abstract AS abstract_CROSSREF,
  pubmed.pubmed_Abstract AS abstract_PUBMED,
 
  ------ 1.5 PUBMED TABLE: CONCATENATED Clinical Trial Registries/Data Banks,and Accession Numbers (optional fields)
  ------- This field is overloaded!
  pubmed.pubmed_DataBankList AS pubmed_DataBankList_RAW,
  TRIM((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList))) AS PUBMED_DataBankList_names_CONCAT,
  TRIM((SELECT STRING_AGG(id, " ") FROM UNNEST(pubmed.pubmed_DataBankList))) AS PUBMED_DataBankList_ids_CONCAT,

  ------ 1.6 CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - PUBMED - contained in fields
  ------- This field is overloaded!
  IF(REGEXP_CONTAINS((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)), 
  'ANZCTR|ChiCTR|CRiS|ClinicalTrials\\.gov|CTRI|DRKS|EudraCT|IRCT|ISRCTN|JapicCTI|JMACCT|JPRN|NTR|PACTR|ReBec|REPEC|RPCEC|SLCTR|TCTR|UMIN CTR|UMIN-CTR'),
  TRUE, FALSE) AS PUBMED_fromfield_trialid_found,
  
  ------ 1.7 CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - PUBMED - Abstract search for trial numbers
  # NOTE, THERE ARE OTHER IDS TO SEARCH ON
 # REGEXP_CONTAINS(UPPER(pubmed.pubmed_Abstract), r'NCT0\\d{7}') as pubmed_has_ClinTrialReg_ID,
 # CASE
 #   WHEN REGEXP_CONTAINS(UPPER(pubmed.pubmed_Abstract), r'NCT0\\d{7}') THEN "Has PubMed Clinical Trial Registry ID"
 #   ELSE "No PubMed Clinical Trial Registry ID found"
 # END as pubmed_has_ClinTrialReg_ID_PRETTY,
 # REGEXP_EXTRACT_ALL(UPPER(pubmed.pubmed_Abstract), r'NCT0\\d{7}') as clinical_trial_gov_trns2,

"" AS PUBMED_fromabstract_trialid,
FALSE AS PUBMED_fromabstract_trialid_found,

  ------ 1.8 PUBMED TABLE: Databank names - details
  IF(REGEXP_CONTAINS((SELECT STRING_AGG(name, " ") FROM UNNEST(pubmed.pubmed_DataBankList)), 
  'BioProject|dbGaP|dbSNP|dbVar|Dryad|figshare|GDB|GENBANK|GEO|OMIM|PIR|PubChem-BioAssay|PubChem-Compound|PubChem-Substance|RefSeq|SRA|SWISSPROT|UniMES|UniParc|UniProtKB|UniRef|PDB|Protein'),
  TRUE, FALSE) AS PUBMED_fromfield_opendata_found,
 -----------------------------------------------------------------------
 FROM
    ------ Crossref from Academic Observatory.
    `academic-observatory.observatory.doi20230618` as academic_observatory
    # PubMed is only included here as the required fields are not yet in the Academic Observatory
    LEFT JOIN `university-of-ottawa.neuro_data_processed.pubmed_extract` as pubmed
      ON LOWER(academic_observatory.doi) = LOWER(pubmed_doi)
      WHERE academic_observatory.crossref.published_year > 2010

 ), # END OF 1. SELECT main_select

-----------------------------------------------------------------------
-- 2A: process_pubmed_databank - flattening the nested Pubmed data
-----------------------------------------------------------------------
table_1 AS (
SELECT 
    doi,
    pubmed_databank_unested1.name AS PUBMED_databank_names,
    pubmed_databank_unested1.id AS PUBMED_databank_ids,
FROM
    main_select ,
    UNNEST(pubmed_DataBankList_RAW) AS pubmed_databank_unested1
), # END. SELECT table_1

-----------------------------------------------------------------------
-- 2: process_pubmed_databank - Getting the DATABANKS
-----------------------------------------------------------------------
table_2 AS (
SELECT
  doi,
  STRING_AGG(PUBMED_databank_names, ' ') AS PUBMED_opendata_fromfield_names,
  STRING_AGG(PUBMED_databank_ids, ' ') AS PUBMED_opendata_fromfield_ids
FROM table_1
WHERE REGEXP_CONTAINS(PUBMED_databank_names,'BioProject|dbGaP|dbSNP|dbVar|Dryad|figshare|GDB|GENBANK|GEO|OMIM|PIR|PubChem-BioAssay|PubChem-Compound|PubChem-Substance|RefSeq|SRA|SWISSPROT|UniMES|UniParc|UniProtKB|UniRef|PDB|Protein')
GROUP by doi
), # END. SELECT table_2

-----------------------------------------------------------------------
-- 3: process_pubmed_registries - Getting the CLINICAL TRIAL Registries
-----------------------------------------------------------------------
table_3 AS (
SELECT
  doi,
  STRING_AGG(PUBMED_databank_names, ' ') AS PUBMED_clintrial_fromfield_names,
  UPPER(STRING_AGG(PUBMED_databank_ids, ' ')) AS PUBMED_clintrial_fromfield_ids
FROM table_1
WHERE REGEXP_CONTAINS(PUBMED_databank_names,'ANZCTR|ChiCTR|CRiS|ClinicalTrials\\.gov|CTRI|DRKS|EudraCT|IRCT|ISRCTN|JapicCTI|JMACCT|JPRN|NTR|PACTR|ReBec|REPEC|RPCEC|SLCTR|TCTR|UMIN CTR|UMIN-CTR')
GROUP by doi
), # END. SELECT table_3

-----------------------------------------------------------------------
-- 4: process_pubmed_registries - Linking Databanks to main query
-----------------------------------------------------------------------
table_4 AS (
SELECT
  main_select.*,
  table2_joined.PUBMED_opendata_fromfield_names,
  table2_joined.PUBMED_opendata_fromfield_ids,
FROM main_select
LEFT JOIN table_2 as table2_joined
  ON LOWER(main_select.doi) = LOWER(table2_joined.doi)
), # END. SELECT table_4

-----------------------------------------------------------------------
-- 5: process_pubmed_registries - Linking CLINICAL TRIAL Registries to main query
-----------------------------------------------------------------------
table_5 AS (
SELECT
  table_4.*,
  table3_joined.PUBMED_clintrial_fromfield_names,
  table3_joined.PUBMED_clintrial_fromfield_ids
FROM table_4
LEFT JOIN table_3 as table3_joined
  ON LOWER(table_4.doi) = LOWER(table3_joined.doi)
) # END. SELECT table_5

-----------------------------------------------------------------------
-- 6: combine trial IDs and registies for BOTH Crossref and Pubmed
-----------------------------------------------------------------------
SELECT
  * EXCEPT (pubmed_DataBankList_RAW),  

  ------ 6.1 Clinical Trial - combine Trial-IDs from all sources
    TRIM(REPLACE(
        CONCAT(COALESCE(CROSSREF_fromfield_trialid,""), " ",
        # The following complex statement is to capture missing (?) values that returns "0 rows" isntead of null
        TRIM(COALESCE((SELECT CONCAT(p1) FROM UNNEST(CROSSREF_fromabstract_trialid) AS p1) ,'')),
        COALESCE(PUBMED_clintrial_fromfield_ids,""), " ", 
        COALESCE(PUBMED_fromabstract_trialid,""), " "
       ),'  ',' ')) AS ANYSOURCE_trialids,
  
  ------ 6.2 Determine if ANY Clinical Trial is found from ANY source
   IF (CROSSREF_fromfield_trialid_found 
    OR CROSSREF_fromabstract_trialid_found
    OR PUBMED_fromfield_trialid_found
    OR PUBMED_fromabstract_trialid_found, 
    TRUE, FALSE) AS ANYSOURCE_trialid_found,

   ------ 6.3 Databanks - combine DATABANK IDs from all sources
    TRIM(REPLACE(
      CONCAT(
        COALESCE(PUBMED_opendata_fromfield_names,""), " ", 
        COALESCE(UPPER(PUBMED_opendata_fromfield_ids),""), " "
       ),'  ',' ')) AS ANYSOURCE_opendata_ids,
  
   ----- 6.4 UTILITY - add a variable for the script version
  var_SQL_script_name

  FROM table_5

# END SELECT #6 Final

