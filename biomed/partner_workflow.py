import os

from biomed.config import Partner, Context
from biomed.queries import alltrials


def partner_workflow(partner: Partner, context: Context):
    create_queries(partner, context)


def create_queries(partner: Partner, context: Context):

    query_alltrials = alltrials(**partner.to_dict(), **context.to_dict())
    # query_alltrials = alltrials(
    #     project=context.project,
    #     run_version=context.run_version,
    #     doi_version=context.doi_version,
    #     institution_id=partner.institution_id,
    #     workflow_hash=context.workflow_hash,
    # )
    save_query(query_alltrials, os.path.join(context.output_dir, f"{partner.institution_id}_alltrials.sql"))


def save_query(query: str, path: str):
    dir = os.path.dirname(path)
    if not os.path.exists(dir):
        raise RuntimeError(f"Directory does not exist: {dir}")

    with open(path, "w") as f:
        f.write(query)
    print(f"Query written to file: {path}")
