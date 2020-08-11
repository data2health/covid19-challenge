"""
Reject submissions that are invalid in UW queue but valid in synthetic queue
"""
import argparse
import time

from challengeutils.annotations import update_submission_status
from challengeutils.utils import (evaluation_queue_query,
                                  update_single_submission_status)
import pandas as pd
import synapseclient
from synapseclient.core.retry import with_retry
from synapseclient import Synapse


def get_queue_mapping(syn):
    """Gets queue mapping dataframe"""
    queue_mapping = syn.tableQuery("select * from syn22077175")
    return queue_mapping.asDataFrame()


class MockResponse:
    """Mocked status code to return"""
    status_code = 200


def annotate_submission(syn: Synapse, submissionid: str,
                        annotation_dict: dict = None, status: str = None,
                        is_private: bool = True,
                        force: bool = False) -> MockResponse:
    """Annotate submission with annotation values from a dict

    Args:
        syn: Synapse object
        submissionid: Submission id
        annotation_dict: Annotation dict
        status: Submission Status
        is_private: Set annotations acl to private (default is True)
        force: Force change the annotation from
               private to public and vice versa.

    Returns:
        MockResponse

    """
    sub_status = syn.getSubmissionStatus(submissionid)
    # Update the status as well
    if status is not None:
        sub_status.status = status
    if annotation_dict is None:
        annotation_dict = {}
    # Don't add any annotations that are None
    annotation_dict = {key: annotation_dict[key] for key in annotation_dict
                       if annotation_dict[key] is not None}
    sub_status = update_single_submission_status(sub_status, annotation_dict,
                                                 is_private=is_private,
                                                 force=force)
    sub_status = update_submission_status(sub_status, annotation_dict)
    syn.store(sub_status)
    return MockResponse


def annotate_with_retry(**kwargs):
    """Annotates submission status with retry to account for
    conflicting submission updates

    Args:
        **kwargs: Takes same parameters as annotate_submission
    """
    with_retry(annotate_submission(**kwargs),
               wait=3,
               retries=10,
               retry_status_codes=[412, 429, 500, 502, 503, 504],
               verbose=True)


def update_status(syn: Synapse, queue_info: pd.Series):
    """If internal submission is invalid, then make update main leaderboard
    with site_submission_status to INVALID

    Args:
        syn: Synapse connection
        queue_info: One row of queue mapping information
                    {"main": main queue
                     "internal": internal queue
                     "site": site}
    """
    # Get submissions that are processing in internal queues
    processing_subs = (
        f"select objectId from evaluation_{queue_info['main']} where "
        f"{queue_info['site']}_submission_status == 'EVALUATION_IN_PROGRESS'"
    )
    processing_submissions = list(
        evaluation_queue_query(syn, processing_subs)
    )
    # For all the submisisons that are processing, obtain the status in
    # the internal queues.  Make main submission invalid.
    for sub in processing_submissions:
        internal_query_str = (
            f"select name from evaluation_{queue_info['internal']} where "
            f"status == 'INVALID' and name == '{sub['objectId']}'"
        )
        internal_subs = list(evaluation_queue_query(syn, internal_query_str))
        if internal_subs:
            internal_status = {
                f"{queue_info['site']}_submission_status": "INVALID"
            }
            annotate_with_retry(syn=syn, submissionid=internal_subs[0]['name'],
                                annotation_dict=internal_status,
                                is_private=False)
            # TODO: email participant here


def convert_overall_status(syn: Synapse, main_queueid: str, sites: list):
    """If all internal sites have INVALID status, make main status REJECTED
    """
    # Format site query str
    site_status_keys = [f"{site}_submission_status == 'INVALID'"
                        for site in sites]
    site_strs = " and ".join(site_status_keys)
    # Get submissions that have all sites that are invalid
    query_str = (
        f"select objectId from evaluation_{main_queueid} where "
        f"{site_strs} and status != 'REJECTED'"
    )
    print(query_str)
    invalid_subs = list(evaluation_queue_query(syn, query_str))
    for invalid_sub in invalid_subs:
        print(invalid_sub['objectId'])
        annotate_with_retry(syn=syn, submissionid=invalid_sub['objectId'],
                            status="REJECTED")


def main():
    """Invoke REJECTION"""
    parser = argparse.ArgumentParser(description='Reject Submissions')
    parser.add_argument('--username', type=str,
                        help='Synapse Username')
    parser.add_argument('--password', type=str,
                        help="Synapse Password")
    args = parser.parse_args()
    syn = synapseclient.Synapse()
    syn.login(email=args.username, password=args.password)
    queue_mappingdf = get_queue_mapping(syn)
    # Group by main queues, because a main queue can be attached
    # to more than one internal queue
    main_queues = queue_mappingdf.groupby("main")
    for main_queueid, queue_df in main_queues:
        evaluation = syn.getEvaluation(main_queueid)
        print(f"Checking '{evaluation.name}'")
        queue_df.apply(lambda queue_info: update_status(syn, queue_info),
                       axis=1)
        time.sleep(5)
        convert_overall_status(syn, main_queueid, queue_df['site'].unique())


if __name__ == "__main__":
    main()
