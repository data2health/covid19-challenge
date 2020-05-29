#!/usr/bin/env python
"""Validation of COVID-19 challenge"""
import argparse
import json

import pandas as pd


def cli():
    """Create CLI for validation"""
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--submission_file",
                        help="Submission File")
    parser.add_argument("-q", "--question", type=int,
                        help="Question number")
    parser.add_argument("-r", "--results", required=True,
                        help="validation results")
    parser.add_argument("-g", "--goldstandard", required=True,
                        help="Goldstandard for scoring")
    args = parser.parse_args()
    return args


def q1_validation(submission_file, goldstandard_file):
    """Q1 validation"""
    invalid_reasons = []
    submission_status = "INVALID"

    try:
        subdf = pd.read_csv(submission_file)
    except pd.errors.EmptyDataError:
        invalid_reasons.append(
            "Your model did not generate a predictions.csv file."
        )
        return submission_status, invalid_reasons

    if subdf.get("score") is None:
        invalid_reasons.append("Submission must have 'score' column")
    else:
        try:
            subdf['score'] = subdf['score'].astype(float)
        except ValueError:
            invalid_reasons.append(
                "Submission 'score' must contain values between 0 and 1"
            )
        if subdf['score'].isnull().any():
            invalid_reasons.append(
                "Submission 'score' must not contain any NA or blank values"
            )
        if not all([0 <= score <= 1 for score in subdf['score']]):
            invalid_reasons.append(
                "Submission 'score' must contain values between 0 and 1"
            )

    if subdf.get("person_id") is None:
        invalid_reasons.append("Submission must have 'person_id' column")
    else:
        goldstandard = pd.read_csv(goldstandard_file)
        if not goldstandard['person_id'].isin(subdf['person_id']).all():
            invalid_reasons.append(
                "Submission 'person_id' does not have scores for all "
                "goldstandard patients.")
        if subdf['person_id'].duplicated().any():
            invalid_reasons.append(
                "Submission has duplicated 'person_id' values."
            )

    if not invalid_reasons:
        submission_status = "ACCEPTED"

    return submission_status, invalid_reasons


def main():
    args = cli()
    func_map = {1: q1_validation}
    validation_func = func_map[args.question]
    submission_status, invalid_reasons = validation_func(
        args.submission_file, args.goldstandard
    )

    result = {'submission_errors': "\n".join(invalid_reasons),
              'submission_status': submission_status}

    with open(args.results, 'w') as result_out:
        result_out.write(json.dumps(result))


if __name__ == "__main__":
    main()
