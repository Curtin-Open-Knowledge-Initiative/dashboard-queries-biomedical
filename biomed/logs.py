from biomed.config import Partner


def bioprint(partner: Partner, log: str):
    """Basic logging"""
    print(f"{partner.institution_id} :: {log}")
