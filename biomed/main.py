import argparse
import yaml

from biomed.gcp import gcp_set_auth, bq_run_query
from biomed.config import Config


def workflow(config: Config):
    gcp_set_auth(config.keyfile)
    query = """
    SELECT name, SUM(number) as total_people
    FROM `bigquery-public-data.usa_names.usa_1910_2013`
    WHERE state = 'TX'
    GROUP BY name, state
    ORDER BY total_people DESC
    LIMIT 20
"""
    rows = bq_run_query(query=query)
    for row in rows:
        print(row)


def main():
    parser = argparse.ArgumentParser(
        description="Biomedical dashboard workflow. Creates and optionally runs the dashboard queries."
    )
    parser.add_argument(
        "config",
        type=str,
        help="The config file containing the run information. See example_config.yaml for an example of the config expectations.",
    )
    args = parser.parse_args()
    with open(args.cfg_file, "r") as f:
        yaml_cfg = yaml.safe_load(f)
    config: Config = Config.from_dict(yaml_cfg)
    workflow(config)
