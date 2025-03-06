import os
from typing import Optional

from google.cloud.bigquery.client import Client
from google.cloud.bigquery.table import RowIterator


def gcp_set_auth(keyfile: str) -> None:
    """Sets the Google Cloud Project authentication environment variable using the provided keyfile"""
    if not os.path.exists(keyfile):
        raise (f"Provided keyfile does not exist: {keyfile}")
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = keyfile


def bq_run_query(query: str, project: Optional[str] = None) -> RowIterator:
    """Runs a query in bigquery.

    :param query: The query to run
    :param project: The name of the project to run the query under. Defaults to the environment project
    """
    client: Client = Client(project=project)
    return client.query_and_wait(query)
