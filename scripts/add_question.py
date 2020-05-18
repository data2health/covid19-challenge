"""Add a challenge question"""
import argparse
import os
import shutil

import synapseclient
from synapseclient import Evaluation, File, Synapse

MASTER = "https://github.com/data2health/covid19-challenge/archive/master.zip"
DEV = "https://github.com/data2health/covid19-challenge/archive/develop.zip"
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))


def create_evaluation_queue(syn: Synapse, name: str) -> Evaluation:
    """Creates evaluation queue

    Args:
        name: Name of queue

    Returns:
        a synapseclient.Evaluation
    """
    queue = Evaluation(name=name, contentSource="syn21849255")
    return syn.store(queue)


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


def create_main_bundle(syn: Synapse, question: int):
    """Creates workflow and entity bundles for the main submission

    Args:
        syn: Synapse connection
        question: Question number
    """
    shutil.copyfile(
        os.path.join(SCRIPT_DIR,
                     "../infrastructure/main_workflow.cwl"),
        os.path.join(SCRIPT_DIR,
                     f"../infrastructure/{question}_workflow.cwl")
    )

    main_queue = create_evaluation_queue(
        syn, f"COVID-19 DREAM Challenge - Question {question}"
    )
    main_queue_test = create_evaluation_queue(
        syn, f"COVID-19 DREAM Challenge - Question {question} TEST"
    )

    prof_wf = os.path.join("covid19-challenge-master/infrastructure",
                           f"{question}_workflow.cwl")
    test_wf = os.path.join("covid19-challenge-develop/infrastructure",
                           f"{question}_workflow.cwl")

    main_ent = create_entity(syn, name=f"COVID-19 Q{question}",
                             link=MASTER,
                             annotations={'ROOT_TEMPLATE': prof_wf})
    main_test_ent = create_entity(syn, name=f"COVID-19 Q{question} TEST",
                                  link=DEV,
                                  annotations={'ROOT_TEMPLATE': test_wf})

    print("Add to NCAT's docker-compose .env")
    print({main_queue.id: main_ent.id,
           main_queue_test.id: main_test_ent.id})


def create_site_bundle(syn: Synapse, question: int, site: str):
    """Creates workflow and entity bundles for the internal site submissions

    Args:
        syn: Synapse connection
        question: Question number
        site: Site
    """
    shutil.copyfile(
        os.path.join(SCRIPT_DIR,
                     "../infrastructure/internal_workflow.cwl"),
        os.path.join(SCRIPT_DIR,
                     f"../infrastructure/{question}_internal_workflow.cwl")
    )

    internal = create_evaluation_queue(
        syn, f"COVID-19 DREAM {site} - Question {question}"
    )
    internal_test = create_evaluation_queue(
        syn, f"COVID-19 DREAM {site} - Question {question} TEST"
    )

    prod_wf = os.path.join("covid19-challenge-master/infrastructure",
                           f"{question}_internal_workflow.cwl")
    test_wf = os.path.join("covid19-challenge-develop/infrastructure",
                           f"{question}_internal_workflow.cwl")

    ent = create_entity(syn, name=f"COVID-19 {site} Q{question}",
                        link=MASTER,
                        annotations={'ROOT_TEMPLATE': prod_wf})
    test_ent = create_entity(syn, name=f"COVID-19 {site} Q{question} TEST",
                             link=DEV,
                             annotations={'ROOT_TEMPLATE': test_wf})

    print(f"Add to {site}'s docker-compose .env")
    print({internal.id: ent.id,
           internal_test.id: test_ent.id})


def cli():
    """Command line interface"""
    parser = argparse.ArgumentParser(description='Process some integers.')
    parser.add_argument('question', type=int,
                        help='A question number to add')
    parser.add_argument('--sites', type=str, nargs='+',
                        help="Sites to add")
    parser.add_argument('--only_internal', action='store_true',
                        help="Only add site workflow bundles")   
    args = parser.parse_args()
    return args


def main():
    """Main"""
    args = cli()
    syn = synapseclient.login()
    question = args.question
    sites = args.sites
    # Create main workflows + entities
    if not args.only_internal:
        create_main_bundle(syn, question)
    for site in sites:
        # Create site workflows + entities
        create_site_bundle(syn, question, site)
    print("Make sure you run")
    print(f"git add infrastructure/{question}_workflow.cwl")
    print(f"git add infrastructure/{question}_internal_workflow.cwl")


if __name__ == "__main__":
    main()
