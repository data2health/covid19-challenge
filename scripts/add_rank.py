"""Add a challenge question"""
import argparse

from challengeutils.utils import (evaluation_queue_query,
                                  update_single_submission_status)
import pandas as pd
import synapseclient


def cli():
    """Command line interface"""
    parser = argparse.ArgumentParser(description='Process some integers.')
    parser.add_argument('evaluationid', type=int,
                        help='A question number to add')
    parser.add_argument('--username', type=str,
                        help='Synapse Username')
    parser.add_argument('--password', type=str,
                        help="Synapse Password")
    args = parser.parse_args()
    return args


def get_score_results(syn, main_queue, internal_queue, site=None):
    """Get score results for site"""
    print("Getting score results")
    dataset_mapping = syn.tableQuery(
        f"SELECT * FROM syn22093564 where queue = '{internal_queue}'"
    )
    dataset_mappingdf = dataset_mapping.asDataFrame()
    if dataset_mappingdf.empty:
        raise ValueError("No queue id")
    dataset_mappingdf = dataset_mappingdf.fillna("")
    # Get dataset info
    dataset_info = dataset_mappingdf.to_dict("record")[0]
    train = dataset_info['train_dataset_version']
    infer = dataset_info['infer_dataset_version']
    query = (
        f"select * from evaluation_{main_queue} where "
        f"{site}_train_dataset_version == '{train}' and "
        f"{site}_infer_dataset_version == '{infer}' and "
        f"{site}_submission_status == 'SCORED'"
    )
    results = list(evaluation_queue_query(syn, query))
    resultsdf = pd.DataFrame(results)
    return resultsdf


def add_rank(syn, resultsdf, site, score_column):
    """Add ranking to submission status"""
    print("Adding rank")
    resultsdf['ranking'] = -1
    sorted_values = resultsdf.sort_values(score_column, ascending=False)
    nodups = sorted_values.drop_duplicates("submitterId")

    resultsdf.loc[nodups.index, 'ranking'] = nodups[score_column].rank(
        ascending=False, method='min'
    )
    resultsdf['ranking'] = resultsdf['ranking'].astype(int)

    for _, row in resultsdf.iterrows():
        # print(row['objectId'])
        sub_status = syn.getSubmissionStatus(row['objectId'])
        updated = update_single_submission_status(
            sub_status, {f"{site}_rank": row['ranking']},
            is_private=False
        )
        syn.store(updated)


def main():
    """Main"""
    args = cli()
    syn = synapseclient.Synapse()
    syn.login(email=args.username, password=args.password)
    queue_id = args.evaluationid
    # TODO: Can loop through main queues instead of specifying
    # a queue
    queue_mapping = syn.tableQuery(
        f"SELECT * FROM syn22077175 where main = '{queue_id}'"
    )
    queue_mappingdf = queue_mapping.asDataFrame()
    if queue_mappingdf.empty:
        raise ValueError("No queue id")
    queue_mapping_dict = queue_mappingdf.to_dict('records')
    for queue_map in queue_mapping_dict:
        internal_queue = queue_map['internal']
        site = queue_map['site']
        resultsdf = get_score_results(syn, queue_id, internal_queue, site)
        # TODO: Need to support different score columns per site
        add_rank(syn, resultsdf, site, "UW_PRAUC")


if __name__ == "__main__":
    main()
