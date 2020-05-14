#!/usr/bin/env cwl-runner
#
# Create an annotation json with the dataset version
#
cwlVersion: v1.0
class: CommandLineTool
# Needs a basecommand, so use echo as a hack
baseCommand: echo

inputs:
  - id: version
    type: string

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: update_status.json
        entry: |
          {"dataset_version": \"$(inputs.version)\"}

outputs:
  - id: json_out
    type: File
    outputBinding:
      glob: update_status.json