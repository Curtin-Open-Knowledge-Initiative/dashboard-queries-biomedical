-----------------------------------------------------------------------
-- Montreal Neuro - Run this 1st
-- See instructions at https://github.com/Curtin-Open-Knowledge-Initiative/dashboard-queries-biomedical
-- Creates a data subset of the Academic Observatory to extract Crossref 
-- and Pubmed data and make a combined list of Clinical trials from these datasets
-----------------------------------------------------------------------
DECLARE var_SQL_script_name STRING DEFAULT 'neuro_ver1o_query1_pubmed_2023_12_11';
DECLARE var_SQL_year_cutoff INT64 DEFAULT 2000;

# --------------------------------------------------
# 0. Setup table 
# --------------------------------------------------
#CREATE TABLE `university-of-ottawa.neuro_dashboard_data_archive.clintrial_extract_ver1o_2023_12_11a`
# AS (

-----------------------------------------------------------------------
-- 1. EXTRACT AND TIDY FIELDS OF INTEREST (except Pubmed clintrial/databank data)
-----------------------------------------------------------------------
WITH main_select AS (
  SELECT
  ------ 1.1 DOI TABLE: Misc METADATA
  academic_observatory.doi as doi,
  academic_observatory.crossref.published_year, -- from doi table

  ------ 1.2 CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - CROSSREF - contained in fields
  academic_observatory.crossref.clinical_trial_number AS CROSSREF_clintrial_fromfield_original,

  CASE
    WHEN academic_observatory.crossref.clinical_trial_number IS NULL THEN FALSE
    WHEN ARRAY_LENGTH(academic_observatory.crossref.clinical_trial_number) > 0 THEN TRUE
    ELSE FALSE
    END as CROSSREF_clintrial_fromfield_found,

#(SELECT clinical_trial_number FROM UNNEST crossref.clinical_trial_number),
#  #n1.clinical_trial_number,
#
#  STRUCT(
#    ARRAY_AGG(##
#
#    ("crossref_field" AS registry,
#    n1.clinical_trial_number AS id,
##    n1.type AS type
#    )) as CROSSREF_clintrial_fromfield,

  # The following field is used for QC
  ARRAY_LENGTH(academic_observatory.crossref.clinical_trial_number) AS CROSSREF_clintrial_fromfield_num,

  ------ 1.3 CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - CROSSREF Abstract search for trial numbers
  CASE
    WHEN academic_observatory.crossref.abstract IS NULL THEN FALSE
    WHEN academic_observatory.crossref.abstract = "" THEN FALSE
    WHEN academic_observatory.crossref.abstract = "{}" THEN FALSE
    WHEN REGEXP_CONTAINS(UPPER(academic_observatory.crossref.abstract), r'NCT0\\d{7}') THEN TRUE
    ELSE FALSE
  END as CROSSREF_clintrial_fromabstract_found,

  # NOTE ###### THIS MAY NOT HANDLE DUPLICATE RETURNED VALUES 

  #
  #REGEXP_EXTRACT_ALL(UPPER(academic_observatory.crossref.abstract), r'NCT0\\d{7}') 
  #  AS CROSSREF_clintrial_fromabstract_ids,
  #

  STRUCT(
    "crossref_abstract" AS registry,
    REGEXP_EXTRACT_ALL(UPPER(academic_observatory.crossref.abstract), r'NCT0\\d{7}') AS id
    ) AS CROSSREF_clintrial_fromabstract,

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
-- 2a, Extract just the CLINICAL TRIAL Registries from the overloaded field
-----------------------------------------------------------------------
pubmed_1_clintrials AS (
 SELECT
   pubmed.doi as doi,   
   ARRAY_AGG(STRUCT(
     ARRAY_CONCAT(p2a.AccessionNumberList) AS clinical_trial_number,
     p2a.DataBankName AS registry
     )) as PUBMED_clintrial_fromfield,
      
  FROM  
   `academic-observatory.observatory.doi20231203` AS academic_observatory,
   UNNEST(pubmed.MedlineCitation.Article.DataBankList) AS p2a

   WHERE academic_observatory.crossref.published_year > var_SQL_year_cutoff AND
   REGEXP_CONTAINS(p2a.DataBankName,'ANZCTR|ChiCTR|CRiS|ClinicalTrials\\.gov|CTRI|DRKS|EudraCT|IRCT|ISRCTN|JapicCTI|JMACCT|JPRN|NTR|PACTR|ReBec|REPEC|RPCEC|SLCTR|TCTR|UMIN CTR|UMIN-CTR')
   
   group by pubmed.doi
), # END. SELECT pubmed_1_clintrials

-----------------------------------------------------------------------
-- 2b, Extract just the DATABANKS from the overloaded field
-----------------------------------------------------------------------
pubmed_2_databanks AS (
 SELECT
   pubmed.doi as doi,   
    
   ARRAY_AGG(STRUCT(
     ARRAY_CONCAT(p2b.AccessionNumberList) AS databank_id,
     p2b.DataBankName AS registry
     )) as PUBMED_opendata_fromfield,
      
  FROM  
   `academic-observatory.observatory.doi20231203` AS academic_observatory,
   UNNEST(pubmed.MedlineCitation.Article.DataBankList) AS p2b

   WHERE academic_observatory.crossref.published_year > var_SQL_year_cutoff AND
   REGEXP_CONTAINS(p2b.DataBankName,'BioProject|dbGaP|dbSNP|dbVar|Dryad|figshare|GDB|GENBANK|GEO|OMIM|PIR|PubChem-BioAssay|PubChem-Compound|PubChem-Substance|RefSeq|SRA|SWISSPROT|UniMES|UniParc|UniProtKB|UniRef|PDB|Protein')
   
   group by pubmed.doi
), # END. SELECT pubmed_2_databanks

-----------------------------------------------------------------------
-- 2z Extract ALL Registry data from the Pubmed data in the DOI table
--   This is done as a seperate processing step as the raw field is
--   overloaded so needs to be unpacked/flattened, the re-combined
--   and renamed
--   This ALL extraction of all data is just for QC
-----------------------------------------------------------------------
pubmed_3_all AS (
 SELECT
   pubmed.doi as doi,   
   ARRAY_AGG(STRUCT(
     ARRAY_CONCAT(p2z.AccessionNumberList) AS id,
     p2z.DataBankName AS registry
     )) as pubmed_extract_ALL,
  FROM  
   `academic-observatory.observatory.doi20231203` AS academic_observatory,
   UNNEST(pubmed.MedlineCitation.Article.DataBankList) AS p2z
   WHERE academic_observatory.crossref.published_year > var_SQL_year_cutoff
   group by doi
), # END. SELECT pubmed_3_all

-----------------------------------------------------------------------
-- 3a: Link Pubmed data to main query - clintrials
-----------------------------------------------------------------------
enhanced_plus_1 AS (
SELECT
  main_select.*,
  enhanced_plus_1_joined.PUBMED_clintrial_fromfield,
  CASE
    WHEN enhanced_plus_1_joined.PUBMED_clintrial_fromfield IS NULL THEN FALSE
  ELSE TRUE
  END AS PUBMED_clintrial_fromfield_found

FROM main_select
  LEFT JOIN pubmed_1_clintrials as enhanced_plus_1_joined
  ON LOWER(main_select.doi) = LOWER(enhanced_plus_1_joined.doi)
), # END enhanced_plus_1

-----------------------------------------------------------------------
-- 3b: Link Pubmed data to main query - Databanks
-----------------------------------------------------------------------
enhanced_plus_2 AS (
SELECT
  enhanced_plus_1.*,
  enhanced_plus_2_joined.PUBMED_opendata_fromfield,
  CASE
    WHEN enhanced_plus_2_joined.PUBMED_opendata_fromfield IS NULL THEN FALSE
  ELSE TRUE
  END AS PUBMED_opendata_fromfield_found

FROM enhanced_plus_1
  LEFT JOIN pubmed_2_databanks as enhanced_plus_2_joined
  ON LOWER(enhanced_plus_1.doi) = LOWER(enhanced_plus_2_joined.doi)
), # END enhanced_plus_2

-----------------------------------------------------------------------
-- 4a: Rename the sub-fields of Crossref's 
---   CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - CROSSREF - contained in fields
-----------------------------------------------------------------------
crossref_renaming AS (
SELECT
  doi,
  ARRAY_AGG(
    STRUCT(
      n1.clinical_trial_number AS A_id,
      n1.type AS A_type
      )
    ) AS CROSSREF_clintrial_fromfield,

 FROM
    main_select,
    UNNEST (CROSSREF_clintrial_fromfield_original) as n1
    GROUP BY doi
),

-----------------------------------------------------------------------
-- 4b: Join the re-named Crossref structure back into the main query
-----------------------------------------------------------------------
enhanced_plus_3 AS (
SELECT
  enhanced_plus_2.* EXCEPT (CROSSREF_clintrial_fromfield_original),
  crossref_renaming_joined.CROSSREF_clintrial_fromfield,

FROM enhanced_plus_2
  LEFT JOIN crossref_renaming as crossref_renaming_joined
  ON LOWER(enhanced_plus_2.doi) = LOWER(crossref_renaming_joined.doi)
) # END enhanced_plus_3

-----------------------------------------------------------------------
-- 5: Combine trial IDs and registies for BOTH Crossref and Pubmed
-----------------------------------------------------------------------
SELECT
  * ,

  ------ 5.1 Tidy clinical trial data from Crossref Abstracts into a structure:
  ------     Uses CROSSREF_clintrial_fromabstract_ids
  ------     This is not done in the main select as that had a complex search

  ------ 5.0 Clinical Trial - combine Trial-IDs from all sources
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

  ------ 5.1 Determine if ANY Clinical Trial is found from ANY source
   IF (CROSSREF_clintrial_fromfield_found 
    OR CROSSREF_clintrial_fromabstract_found
    OR PUBMED_clintrial_fromfield_found
    OR PUBMED_clintrial_fromabstract_found, 
    TRUE, FALSE) AS ANYSOURCE_clintrial_found,
  
    ----- 5.2 UTILITY - add a variable for the script version
  var_SQL_script_name

  FROM enhanced_plus_3
  WHERE CROSSREF_clintrial_fromfield_num < 4
  ORDER BY CROSSREF_clintrial_fromfield_num DESC
  limit 1000

#) # End create table
 
#where doi = '10.1002/HUMU.10140'
#OR doi  = '10.1186/S12884-017-1594-Z' 
