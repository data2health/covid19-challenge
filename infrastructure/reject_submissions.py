"""
Reject submissions that are invalid in UW queue but valid in synthetic queue
"""
import synapseclient

from challengeutils.utils import evaluation_queue_query


def main():
    """Invoke REJECTION"""
    syn = synapseclient.login()
    main_queue = "9614309"
    uw_queue = "9614308"
    main_query_str = (f"select objectId from evaluation_{main_queue} where "
                      "prediction_file_status == 'VALIDATED' "
                      "and status == 'ACCEPTED'")
    main_subs = list(evaluation_queue_query(syn, main_query_str))
    uw_query_str = (f"select name from evaluation_{uw_queue} where "
                    "status == 'INVALID'")
    uw_subs = list(evaluation_queue_query(syn, uw_query_str))

    invalid_submissions = [sub['name'] for sub in uw_subs]
    for sub in main_subs:
        subid = sub['objectId']
        if subid in invalid_submissions:
            print(subid)
            submission = syn.getSubmissionStatus(subid)
            submission.status = "REJECTED"
            syn.store(submission)

if __name__ == "__main__":
    main()
