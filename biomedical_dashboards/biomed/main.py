import argparse
from concurrent.futures import ThreadPoolExecutor
import os
import traceback
import yaml

from biomedical_dashboards.biomed.config import Config
from biomedical_dashboards.biomed.gcp import gcp_set_auth
from biomedical_dashboards.biomed.partner_workflow import partner_workflow


def workflow(config: Config):
    """Does all of the things."""

    if config.context.dryrun == False:
        gcp_set_auth(config.context.keyfile)
        print("Set authentication with GCP")

    with ThreadPoolExecutor(max_workers=os.cpu_count()) as executor:
        futures = {}
        for partner in config.partners:
            futures[partner.institution_id] = executor.submit(partner_workflow, partner, config.context)

    errors = {}
    for id, f in futures.items():
        try:
            f.result()
        except Exception:
            errors[id] = traceback.format_exc()

    if errors:
        msg = ""
        for id, err in errors.items():
            msg += f"\n---------------------------- {id} ----------------------------\n"
            msg += err
        print("\n")
        print("-----------------------------------------------------------------")
        raise RuntimeError(f"The following errors occurred during the workflow: \n\t{msg}")


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
    with open(args.config, "r") as f:
        yaml_cfg = yaml.safe_load(f)
    config: Config = Config.from_dict(yaml_cfg)
    workflow(config)


if __name__ == "__main__":
    main()
