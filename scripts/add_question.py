"""Add a challenge question"""
import argparse
import os
# import shutil
# from urllib.parse import quote

import synapseclient
from synapseclient import Evaluation, File, Synapse
from synapseclient.core.exceptions import SynapseHTTPError

MASTER = "https://github.com/data2health/covid19-challenge/archive/master.zip"
DEV = "https://github.com/data2health/covid19-challenge/archive/develop.zip"
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))


# def create_workflow():
    # shutil.copyfile(
    #     os.path.join(SCRIPT_DIR,
    #                  "../infrastructure/main_workflow.cwl"),
    #     os.path.join(SCRIPT_DIR,
    #                  f"../infrastructure/{question}_workflow.cwl")
    # )

    # wf_path = os.path.join("covid19-challenge-master/infrastructure",
    #                        f"{question}_workflow.cwl")

    # main_ent = create_entity(syn, name=f"COVID-19 Q{question}",
    #                          link=MASTER,
    #                          annotations={'ROOT_TEMPLATE': wf_path})
    # main_test_ent = create_entity(syn, name=f"COVID-19 Q{question} TEST",
    #                               link=DEV,
    #                               annotations={'ROOT_TEMPLATE': wf_path})


def create_evaluation_queue(syn: Synapse, name: str) -> Evaluation:
    """Creates evaluation queue

    Args:
        name: Name of queue

    Returns:
        a synapseclient.Evaluation
    """
    queue = Evaluation(name=name, contentSource="syn21849255")
    try:
        queue = syn.store(queue)
    except SynapseHTTPError:
        queue = syn.getEvaluationByName(name)
    return queue


def create_entity(syn: Synapse, name: str, link: str,
                  annotations: dict) -> File:
    """Creates evaluation queue

    Args:
        name: Name of queue

    Returns:
        a synapseclient.Evaluation
    """
    file_ent = File(name=name, path=link, parentId="syn21897226",
                    synapseStore=False)
    file_ent.annotations = annotations
    return syn.store(file_ent)


def append_queue_mapping(syn: Synapse, main_queueid: str,
                         internal_queueid: str, site: str):
    """Append to queue mapping if mapping doesn't exist"""
    queue_mapping_table = syn.tableQuery(
        f"select * from syn22077175 where main = '{main_queueid}'"
    )
    queue_mappingdf = queue_mapping_table.asDataFrame()
    if queue_mappingdf.empty:
        table = synapseclient.Table(
            "syn22077175", [[str(main_queueid), str(internal_queueid), site]]
        )
        syn.store(table)


def create_main_bundle(syn: Synapse, question: int) -> dict:
    """Creates workflow and entity bundles for the main submission

    Args:
        syn: Synapse connection
        question: Question number

    Returns:
        main_queueid
        main_testqueueid

    """
    main_queue = create_evaluation_queue(
        syn, f"COVID-19 DREAM Challenge - Question {question}"
    )
    # Global view
    syn.setPermissions(main_queue, accessType=['READ'])
    # Participant team
    syn.setPermissions(
        main_queue, accessType=['READ'], principalId=3407543
    )
    # Admin team
    syn.setPermissions(
        main_queue,
        accessType=['DELETE_SUBMISSION', 'DELETE', 'SUBMIT', 'UPDATE',
                    'CREATE', 'READ', 'UPDATE_SUBMISSION',
                    'READ_PRIVATE_SUBMISSION', 'CHANGE_PERMISSIONS'],
        principalId=3407544
    )

    main_queue_test = create_evaluation_queue(
        syn, f"COVID-19 DREAM Challenge - Question {question} TEST"
    )
    syn.setPermissions(
        main_queue_test,
        accessType=['DELETE_SUBMISSION', 'DELETE', 'SUBMIT', 'UPDATE',
                    'CREATE', 'READ', 'UPDATE_SUBMISSION',
                    'READ_PRIVATE_SUBMISSION', 'CHANGE_PERMISSIONS'],
        principalId=3407544
    )

    print("ACTION ITEM-Add to NCAT's docker-compose .env")
    print({main_queue.id: "syn21897228",
           main_queue_test.id: "syn21897227"})
    return {"main_queueid": main_queue.id,
            "main_queue_testid": main_queue_test.id}


def create_site_bundle(syn: Synapse, question: int, site: str) -> dict:
    """Creates workflow and entity bundles for the internal site submissions

    Args:
        syn: Synapse connection
        question: Question number
        site: Site

    Returns:
        internal_queueid
        internal_testqueueid
    """
    internal = create_evaluation_queue(
        syn, f"COVID-19 DREAM {site} - Question {question}"
    )
    syn.setPermissions(
        internal,
        accessType=['DELETE_SUBMISSION', 'DELETE', 'SUBMIT', 'UPDATE',
                    'CREATE', 'READ', 'UPDATE_SUBMISSION',
                    'READ_PRIVATE_SUBMISSION', 'CHANGE_PERMISSIONS'],
        principalId=3407544
    )
    internal_test = create_evaluation_queue(
        syn, f"COVID-19 DREAM {site} - Question {question} TEST"
    )

    syn.setPermissions(
        internal_test,
        accessType=['DELETE_SUBMISSION', 'DELETE', 'SUBMIT', 'UPDATE',
                    'CREATE', 'READ', 'UPDATE_SUBMISSION',
                    'READ_PRIVATE_SUBMISSION', 'CHANGE_PERMISSIONS'],
        principalId=3407544
    )

    wf_path = os.path.join("covid19-challenge-master/infrastructure",
                           "internal_workflow.cwl")

    ent = create_entity(syn, name=f"COVID-19 Internal {site}",
                        link=MASTER,
                        annotations={'ROOT_TEMPLATE': wf_path})
    test_ent = create_entity(syn, name=f"COVID-19 Internal {site} TEST",
                             link=DEV,
                             annotations={'ROOT_TEMPLATE': wf_path})

    print(f"ACTION ITEM-Add to {site}'s docker-compose .env")
    print({internal.id: ent.id,
           internal_test.id: test_ent.id})
    return {"internal_queueid": internal.id,
            "internal_queue_testid": internal_test.id}


def append_dataset_mapping(syn: Synapse, queue: str, site: str):
    """Append to dataset mapping if mapping doesn't exist"""
    queue_mapping_table = syn.tableQuery(
        f"select * from syn22093564 where queue = '{queue}'"
    )
    queue_mappingdf = queue_mapping_table.asDataFrame()
    if queue_mappingdf.empty:
        table = synapseclient.Table(
            "syn22093564", [[str(queue), site, '', '', '']]
        )
        syn.store(table)


def add_results_leaderboard(syn: Synapse, question: int, sites: list,
                            queue: str):
    """Adding results leaderboard"""

    result_md = ("This page lists the performance of the models submitted to "
                 f"Challenge Question {question}.\n\n"
                 "${toc}\n\n---\n\n")
    result_md_path = os.path.join(SCRIPT_DIR, "results.md")
    for site in sites:
        with open(result_md_path, "r")  as results_f:
            markdown_text = results_f.read()
            markdown_text = markdown_text.replace("INTERNAL", site)
            markdown_text = markdown_text.replace("QUEUEID", queue)
        result_md += markdown_text
    results_wiki = synapseclient.Wiki(title=f"Question {question} Results",
                                      markdown=result_md,
                                      owner="syn21849256",
                                      parentWikiId="601869")
    wiki = syn.store(results_wiki)
    print(
        "ACTION ITEM-"
        f"Revise https://www.synapse.org/#!Synapse:syn21849256/wiki/{wiki.id}"
    )


def add_dashboard_leaderboard(syn: Synapse, question: int, queue: str):
    """Adding dashboard leaderboard"""
    dashboard_md = ("This page lists the status and performance of the "
                    "models that you have submitted to Challenge "
                    f"Question {question}.")
    dashboard_md_path = os.path.join(SCRIPT_DIR, "dashboard.md")
    with open(dashboard_md_path, "r")  as results_f:
        markdown_text = results_f.read()
        markdown_text = markdown_text.replace("QUEUEID", queue)

    dashboard_md += markdown_text
    dashboard_wiki = synapseclient.Wiki(title=f"Question {question} Dashboard",
                                        markdown=dashboard_md,
                                        owner="syn21849256",
                                        parentWikiId="601879")
    wiki = syn.store(dashboard_wiki)
    print(
        "ACTION ITEM-"
        f"Revise https://www.synapse.org/#!Synapse:syn21849256/wiki/{wiki.id}"
    )


def add_internal_live_leaderboard(syn: Synapse, question: int, sites: list,
                                  queue: str):
    """Adding live leaderboard"""
    live_md_path = os.path.join(SCRIPT_DIR, "live.md")
    all_text = ''
    for site in sites:
        with open(live_md_path, "r")  as live_f:
            markdown_text = live_f.read()
            markdown_text = markdown_text.replace("INTERNAL", site)
            markdown_text = markdown_text.replace("QUEUEID", queue)
            markdown_text = markdown_text.replace("NUM", question)
        all_text += markdown_text
    live_wiki = synapseclient.Wiki(title=f"Internal Q{question} Live Results",
                                   markdown=all_text,
                                   owner="syn21849256",
                                   parentWikiId="601940")
    wiki = syn.store(live_wiki)
    print(
        "ACTION ITEM-"
        f"Revise https://www.synapse.org/#!Synapse:syn21849256/wiki/{wiki.id}"
    )


def add_internal_expert_leaderboard():
    pass


def add_internal_test_leaderboard():
    pass


def cli():
    """Command line interface"""
    parser = argparse.ArgumentParser(description='Process some integers.')
    parser.add_argument('question', type=int,
                        help='A question number to add')
    parser.add_argument('--sites', type=str, nargs='+',
                        help="Sites to add")
    args = parser.parse_args()
    return args


def main():
    """Main"""
    args = cli()
    syn = synapseclient.login()
    question = args.question
    sites = args.sites
    # Create main workflows + entities
    #if not args.only_internal:
    main_queue = create_main_bundle(syn, question)
    append_dataset_mapping(syn, main_queue['main_queueid'], "NCATS")
    append_dataset_mapping(syn, main_queue['main_queue_testid'], "NCATS")

    for site in sites:
        # Create site workflows + entities
        internal = create_site_bundle(syn, question, site)
        # Append queue mapping
        append_queue_mapping(syn, main_queue['main_queueid'],
                             internal['internal_queueid'], site)
        append_queue_mapping(syn, main_queue['main_queue_testid'],
                             internal['internal_queue_testid'], site)
        # Append dataset mapping
        append_dataset_mapping(syn, internal['internal_queueid'], site)
        append_dataset_mapping(syn, internal['internal_queue_testid'], site)

    print("ACTION ITEM-Update table syn22093564 with dataset version/name")
    print(
        "ACTION ITEM-Update Results"
        "https://www.synapse.org/#!Synapse:syn21849256/wiki/601940"
    )
    add_results_leaderboard(syn, question, sites, main_queue['main_queueid'])
    print(
        "ACTION ITEM-Update Submission Dashboards"
        "https://www.synapse.org/#!Synapse:syn21849256/wiki/601879"
    )
    add_dashboard_leaderboard(syn, question, main_queue['main_queueid'])
    print(
        "ACTION ITEM-Update Internal Leaderboard"
        "https://www.synapse.org/#!Synapse:syn21849256/wiki/601940"
    )
    add_internal_live_leaderboard(syn, question, sites,
                                  main_queue['main_queueid'])


if __name__ == "__main__":
    main()
