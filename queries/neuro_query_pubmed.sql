-----------------------------------------------------------------------
-- Montreal Neuro - Run this 1st
-- See instructions at https://github.com/Curtin-Open-Knowledge-Initiative/dashboard-queries-biomedical
-- Creates a data subset of the Academic Observatory to extract Crossref 
-- and Pubmed data and make a combined list of Clinical trials from these datasets
-----------------------------------------------------------------------
DECLARE var_SQL_script_name STRING DEFAULT 'neuro_ver1o_query1_pubmed_2023_12_04';
DECLARE var_SQL_year_cutoff INT64 DEFAULT 2000;

# --------------------------------------------------
# 0. Setup table 
# --------------------------------------------------
CREATE TABLE `university-of-ottawa.neuro_dashboard_data_archive.clintrial_extract_ver1o_2023_12_04b`
 AS (

-----------------------------------------------------------------------
-- 1. EXTRACT AND TIDY FIELDS OF INTEREST (except Pubmed clintrial/databank data)
-----------------------------------------------------------------------
WITH main_select AS (
  SELECT
  ------ 1.1 DOI TABLE: Misc METADATA
  academic_observatory.doi as doi,
  academic_observatory.crossref.published_year, -- from doi table

  ------ 1.2 CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - CROSSREF - contained in fields
  academic_observatory.crossref.clinical_trial_number AS CROSSREF_clintrial_fromfield,
  ARRAY_LENGTH(academic_observatory.crossref.clinical_trial_number) AS CROSSREF_clintrial_fromfield_num,

#  (SELECT array_agg(registry)[offset(0)]
#     FROM UNNEST(academic_observatory.crossref.clinical_trial_number))
#     AS CROSSREF_clintrial_fromfield_registry,

#  (SELECT array_agg(type)[offset(0)]
#     FROM UNNEST(academic_observatory.crossref.clinical_trial_number))
#     AS CROSSREF_clintrial_fromfield_type,

#  UPPER(TRIM((SELECT REPLACE(TRIM(array_agg(clinical_trial_number)[offset(0)]),'  ', ' ')
#     FROM UNNEST(academic_observatory.crossref.clinical_trial_number))))
#     AS CROSSREF_clintrial_fromfield_ids,

  CASE
    WHEN academic_observatory.crossref.clinical_trial_number IS NULL THEN FALSE
    WHEN ARRAY_LENGTH(academic_observatory.crossref.clinical_trial_number) > 0 THEN TRUE
    ELSE FALSE
  END as CROSSREF_clintrial_fromfield_found,
  
  ------ 1.3 CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - CROSSREF Abstract search for trial numbers
  # NOTE ###### THIS MAY NOT HANDLE DUPLICATE RETURNED VALUES 
  REGEXP_EXTRACT_ALL(UPPER(academic_observatory.crossref.abstract), r'NCT0\\d{7}') 
    AS CROSSREF_clintrial_fromabstract_ids,

  CASE
    WHEN academic_observatory.crossref.abstract IS NULL THEN FALSE
    WHEN academic_observatory.crossref.abstract = "" THEN FALSE
    WHEN academic_observatory.crossref.abstract = "{}" THEN FALSE
    WHEN REGEXP_CONTAINS(UPPER(academic_observatory.crossref.abstract), r'NCT0\\d{7}') THEN TRUE
    ELSE FALSE
  END as CROSSREF_clintrial_fromabstract_found,

  ------ 1.4 ABSTRACTS from any sources
  academic_observatory.crossref.abstract AS abstract_CROSSREF,  
  pubmed.MedlineCitation.Article.Abstract.AbstractText AS abstract_PUBMED,

  "" AS PUBMED_clintrial_fromabstract_ids, # adding dummy values
  FALSE AS PUBMED_clintrial_fromabstract_found # adding dummy values
 -----------------------------------------------------------------------
 FROM
    ------ Crossref from Academic Observatory.
    `academic-observatory.observatory.doi20231203` AS academic_observatory
    WHERE academic_observatory.crossref.published_year > 2000

 ), # END OF 1. SELECT main_select

-----------------------------------------------------------------------
-- 2a Extract the Registry data from the Pubmed data in the DOI table
--   This is done as a seperate processing step as the raw field is
--   overloaded so needs to be unpacked/flattened, the re-combined
--   and renamed
-----------------------------------------------------------------------
pubmed_tidy_2a AS (
 SELECT
   pubmed.doi as doi,   
   ARRAY_AGG(STRUCT(
     p2a.DataBankName AS name,
     ARRAY_CONCAT(p2a.AccessionNumberList) AS id
     )) as pubmed_extract_ALL,
  FROM  
   `academic-observatory.observatory.doi20231203` AS academic_observatory,
   UNNEST(pubmed.MedlineCitation.Article.DataBankList) AS p2a
   WHERE academic_observatory.crossref.published_year > var_SQL_year_cutoff
   group by doi
), # END. SELECT pubmed_tidy_2a

-----------------------------------------------------------------------
-- 2b, Extract just the CLINICAL TRIAL Registries from the overloaded field
-----------------------------------------------------------------------
pubmed_tidy_2b AS (
 SELECT
   pubmed.doi as doi,   
   ARRAY_AGG(STRUCT(
     p2b.DataBankName AS name,
     ARRAY_CONCAT(p2b.AccessionNumberList) AS id
     )) as PUBMED_clintrial_fromfield,
      
  FROM  
   `academic-observatory.observatory.doi20231203` AS academic_observatory,
   UNNEST(pubmed.MedlineCitation.Article.DataBankList) AS p2b

   WHERE academic_observatory.crossref.published_year > var_SQL_year_cutoff AND
   REGEXP_CONTAINS(p2b.DataBankName,'ANZCTR|ChiCTR|CRiS|ClinicalTrials\\.gov|CTRI|DRKS|EudraCT|IRCT|ISRCTN|JapicCTI|JMACCT|JPRN|NTR|PACTR|ReBec|REPEC|RPCEC|SLCTR|TCTR|UMIN CTR|UMIN-CTR')
   
   group by pubmed.doi
), # END. SELECT pubmed_tidy_2b

-----------------------------------------------------------------------
-- 2c, Extract just the DATABANKS from the overloaded field
-----------------------------------------------------------------------
pubmed_tidy_2c AS (
 SELECT
   pubmed.doi as doi,   
    
   ARRAY_AGG(STRUCT(
     p2c.DataBankName AS name,
     ARRAY_CONCAT(p2c.AccessionNumberList) AS id
     )) as PUBMED_opendata_fromfield,
      
  FROM  
   `academic-observatory.observatory.doi20231203` AS academic_observatory,
   UNNEST(pubmed.MedlineCitation.Article.DataBankList) AS p2c

   WHERE academic_observatory.crossref.published_year > var_SQL_year_cutoff AND
   REGEXP_CONTAINS(p2c.DataBankName,'BioProject|dbGaP|dbSNP|dbVar|Dryad|figshare|GDB|GENBANK|GEO|OMIM|PIR|PubChem-BioAssay|PubChem-Compound|PubChem-Substance|RefSeq|SRA|SWISSPROT|UniMES|UniParc|UniProtKB|UniRef|PDB|Protein')
   
   group by pubmed.doi
), # END. SELECT pubmed_tidy_2c

-----------------------------------------------------------------------
-- 3a: Link Pubmed data to main query - ALL
-----------------------------------------------------------------------
/*
table_3a AS (
SELECT
  main_select.*,
  table_3a_joined.pubmed_extract_ALL,

FROM main_select
  LEFT JOIN pubmed_tidy_2a as table_3a_joined
  ON LOWER(main_select.doi) = LOWER(table_3a_joined.doi)
), # END table_3a
*/
-----------------------------------------------------------------------
-- 3b: Link Pubmed data to main query - clintrial
-----------------------------------------------------------------------
table_3b AS (
SELECT
  main_select.*,
  table_3b_joined.PUBMED_clintrial_fromfield,
  CASE
    WHEN table_3b_joined.PUBMED_clintrial_fromfield IS NULL THEN FALSE
  ELSE TRUE
  END AS PUBMED_clintrial_fromfield_found

FROM main_select
  LEFT JOIN pubmed_tidy_2b as table_3b_joined
  ON LOWER(main_select.doi) = LOWER(table_3b_joined.doi)
), # END table_3b

-----------------------------------------------------------------------
-- 3c: Link Pubmed data to main query - OpenData
-----------------------------------------------------------------------
table_3c AS (
SELECT
  table_3b.*,
  table_3c_joined.PUBMED_opendata_fromfield,
  CASE
    WHEN table_3c_joined.PUBMED_opendata_fromfield IS NULL THEN FALSE
  ELSE TRUE
  END AS PUBMED_opendata_fromfield_found

FROM table_3b
  LEFT JOIN pubmed_tidy_2c as table_3c_joined
  ON LOWER(table_3b.doi) = LOWER(table_3c_joined.doi)
) # END table_3c

-----------------------------------------------------------------------
-- 4: Combine trial IDs and registies for BOTH Crossref and Pubmed
-----------------------------------------------------------------------
SELECT
  *,
  ------ 4.0 Clinical Trial - combine Trial-IDs from all sources
  ------ NOTE: This has been commented out for now

  #  TRIM(REPLACE(
  #      CONCAT(COALESCE(CROSSREF_clintrial_fromfield_ids,""), " ",
  #      # The following complex statement is to capture missing (?) values that returns "0 rows" isntead of null
  #      TRIM(COALESCE((SELECT CONCAT(p1) FROM UNNEST(CROSSREF_clintrial_fromabstract_ids) AS p1) ,'')),
  #      COALESCE(PUBMED_clintrial_fromfield_ids,""), " ", 
  #      COALESCE(PUBMED_clintrial_fromabstract_ids,""), " "
  #     ),'  ',' ')) AS ANYSOURCE_clintrial_ids,

CROSSREF_clintrial_fromfield
AS ANYSOURCE_clintrial_ids,

  ------ 4.1 Determine if ANY Clinical Trial is found from ANY source
   IF (CROSSREF_clintrial_fromfield_found 
    OR CROSSREF_clintrial_fromabstract_found
    OR PUBMED_clintrial_fromfield_found
    OR PUBMED_clintrial_fromabstract_found, 
    TRUE, FALSE) AS ANYSOURCE_clintrial_found,
  
    ----- 4.2 UTILITY - add a variable for the script version
  var_SQL_script_name

  FROM table_3c

) # End create table
 
#where doi = '10.1002/HUMU.10140'
#OR doi  = '10.1186/S12884-017-1594-Z' 
