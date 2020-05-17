#!/usr/bin/env cwl-runner
#
# Create an annotation json with the dataset version
#
cwlVersion: v1.0
class: CommandLineTool
# Needs a basecommand, so use echo as a hack
baseCommand: echo

inputs:
  - id: train_name
    type: string
  - id: train_version
    type: string
  - id: infer_name
    type: string
  - id: infer_version
    type: string

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: update_status.json
        entry: |
          {"train_dataset_name": \"$(inputs.train_name)\",
           "train_dataset_version": \"$(inputs.train_version)\",
           "infer_dataset_name": \"$(inputs.infer_name)\",
           "infer_dataset_version": \"$(inputs.infer_version)\",
           "submission_status": \"EVALUATION_IN_PROGRESS\",
           "train_volume": \"$(inputs.train_name)_$(inputs.train_version)\",
           "infer_volume": \"$(inputs.infer_name)_$(inputs.infer_version)\"}

outputs:
  - id: json_out
    type: File
    outputBinding:
      glob: update_status.json

  - id: train_volume
    type: string
    outputBinding:
      glob: update_status.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['train_volume'])

  - id: infer_volume
    type: string
    outputBinding:
      glob: update_status.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['infer_volume'])