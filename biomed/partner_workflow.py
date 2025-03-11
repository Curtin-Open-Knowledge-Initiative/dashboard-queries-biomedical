from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Tuple
import os

from biomed.gcp import bq_check_table_exists, bq_create_dataset, bq_run_query
from biomed.config import Partner, Context
from biomed.queries import query_alltrials, query_trials, query_pubs, query_orcid


def partner_workflow(partner: Partner, context: Context) -> None:
    """Workflow for a single partner. Does the following:
    - Checks that the static tables exist
    - Creates output datasets if they don't exist
    - Generates the queries and writes them to file
    - Runs the queries

    If context.dryrun setting is enabled, will only create and output the queries.
    """
    # Check/make datasets
    if not context.dryrun:
        check_tables_exist(partner=partner, context=context)
        bq_create_dataset(project=context.project, dataset=partner.output_dataset, exists_ok=True)
        bq_create_dataset(project=context.project, dataset=partner.latest_dataset, exists_ok=True)

    # Query creation
    create_queries(partner=partner, context=context)

    # # Query run
    # if not context.dryrun:
    #     run_queries()


def check_tables_exist(partner: Partner, context: Context):
    """Checks that the static tables exist"""

    def _wrapped_check(project, dataset, table_name) -> Tuple[bool, str]:
        """Wrapped function that also returns the table name"""
        return (bq_check_table_exists(project, dataset, table_name), table_name)

    table_names = [
        partner.trials_aact_table_name,
        partner.dois_table_name,
        partner.oddpub_table_name,
        partner.orcid_table_name,
    ]
    futures = []
    with ThreadPoolExecutor(max_workers=4) as executor:
        for t in table_names:
            futures.append(executor.submit(_wrapped_check, context.project, partner.static_dataset, t))

    errors = []
    for f in as_completed(futures):
        result = f.result()
        if result[0] == False:
            errors.append(f"{context.project}.{partner.static_dataset}.{result[1]}")
    if errors:
        msg = "\n\t".join(errors)
        raise RuntimeError(f"Expected table(s) missing:\n\t{msg}")


def create_queries(partner: Partner, context: Context) -> None:
    """Generates all of the queries for the partner and saves them to file"""

    # Create queries
    alltrials = query_alltrials(**partner.to_dict(), **context.to_dict())
    trials = query_trials(**partner.to_dict(), **context.to_dict())
    pubs = query_pubs(**partner.to_dict(), **context.to_dict())
    orcid = query_orcid(**partner.to_dict(), **context.to_dict())

    # Save queries to file
    save_query(alltrials, os.path.join(context.output_dir, partner.alltrials_query_fname))
    save_query(trials, os.path.join(context.output_dir, partner.trials_query_fname))
    save_query(pubs, os.path.join(context.output_dir, partner.pubs_query_fname))
    save_query(orcid, os.path.join(context.output_dir, partner.orcid_query_fname))


def run_queries(partner: Partner, context: Context) -> None:
    """Reads the queries from file and runs them"""

    for query_fname in [
        partner.orcid_query_fname,
        partner.trials_query_fname,
        partner.pubs_query_fname,
        partner.orcid_query_fname,
    ]:
        with open(query_fname) as f:
            query = f.read()
        bq_run_query(context.project, query)


def save_query(query: str, path: str) -> None:
    dir = os.path.dirname(path)
    if not os.path.exists(dir):
        raise RuntimeError(f"Directory does not exist: {dir}")

    with open(path, "w") as f:
        f.write(query)
    print(f"Query written to file: {path}")
