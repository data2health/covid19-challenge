#!/usr/bin/env cwl-runner
# Submit to challenge

cwlVersion: v1.0
class: Workflow

requirements:
  ScatterFeatureRequirement: {}

inputs:
  evaluationid: string[] 
  submission_file: string
  synapse_config: File
  submissionid: int

steps:
  submit:
    run: submit_to_challenge.cwl
    scatter: evaluationid
    in:
      submission_file: submission_file
      submissionid: submissionid
      synapse_config: synapse_config
      evaluationid: evaluationid
    out: []

outputs: []