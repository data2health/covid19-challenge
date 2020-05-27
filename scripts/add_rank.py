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
    args = parser.parse_args()
    return args


def main():
    """Main"""
    args = cli()
    syn = synapseclient.login()
    queue_id = args.evaluationid

    queue_mapping = syn.tableQuery(
        f"SELECT * FROM syn22077175 where main = '{queue_id}'"
    )
    queue_mappingdf = queue_mapping.asDataFrame()
    if queue_mappingdf.empty:
        raise ValueError("No queue id")
    # TODO: use site record here to get dataset version
    internal_queue = queue_mappingdf['internal'].iloc[0]
    # TODO: Need to support multiple internal queue rankings
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
        f"select * from evaluation_{queue_id} where "
        f"UW_train_dataset_version == '{train}' and "
        f"UW_infer_dataset_version == '{infer}' and "
        "UW_submission_status == 'SCORED'"
    )
    results = list(evaluation_queue_query(syn, query))
    resultsdf = pd.DataFrame(results)
    resultsdf['ranking'] = -1
    sorted_values = resultsdf.sort_values("UW_PRAUC", ascending=False)
    nodups = sorted_values.drop_duplicates("submitterId")

    resultsdf.loc[nodups.index, 'ranking'] = nodups['UW_PRAUC'].rank(
        ascending=False, method='min'
    )
    resultsdf['ranking'] = resultsdf['ranking'].astype(int) 
    for index, row in resultsdf.iterrows():
        print(row['objectId'])
        sub_status = syn.getSubmissionStatus(row['objectId'])
        updated = update_single_submission_status(
            sub_status, {'ranking': row['ranking']},
            is_private=False
        )
        syn.store(updated)


if __name__ == "__main__":
    main()
