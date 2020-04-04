#!/usr/bin/env cwl-runner
#
# Example score submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v2.0.0

inputs:
  - id: status
    type: string
  - id: submissionid
    type: int
  - id: synapse_config
    type: File
  - id: parentid
    type: string
  - id: evaluationid
    type: string
  - id: previous_annotation_finished
    type: boolean?
  - id: previous_email_finished
    type: boolean?

arguments:
  - valueFrom: submit.py
  - valueFrom: $(inputs.status)
    prefix: -s
  - valueFrom: submission.json
    prefix: -r
  - valueFrom: $(inputs.submissionid)
    prefix: -i
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.parentid)
    prefix: --parentid
  - valueFrom: $(inputs.evaluationid)
    prefix: -e

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: submit.py
        entry: |
          #!/usr/bin/env python
          import synapseclient
          import argparse
          import json

          parser = argparse.ArgumentParser()
          parser.add_argument("-s", "--status", required=True, help="Submission status")
          parser.add_argument("-r", "--results", required=True, help="Scoring results")
          parser.add_argument("-i", "--submissionid", required=True, help="Submission ID")
          parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
          parser.add_argument("--parentid", required=True, help="Parent Id of submitter directory")
          parser.add_argument("-e", "--evaluationid", required=True, help="Internal evaluation id")

          args = parser.parse_args()
          syn = synapseclient.Synapse(configPath=args.synapse_config)
          syn.login()
          if args.status.startswith("VALID"):
            submission_dict = {"submissionid": int(args.submissionid)}
            with open(args.results, 'w') as json_file:
              json_file.write(json.dumps(submission_dict))
            submission_file = synapseclient.File(args.results, parentId=args.parentid)
            submission_file_ent = syn.store(submission_file)
            submission_status = {"prediction_file_status": "EVALUATION_IN_PROGRESS"}
            syn.submit(evaluation=args.evaluationid, entity=submission_file_ent, name=args.submissionid)
          else:
            submission_status = {"prediction_file_status": "INVALID"}
          with open('update_status.json', 'w') as status_file:
            status_file.write(json.dumps(submission_status))

outputs:
  - id: json_out
    type: File
    outputBinding:
      glob: update_status.json