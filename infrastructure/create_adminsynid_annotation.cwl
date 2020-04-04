#!/usr/bin/env cwl-runner
#
# Create an annotation json with the admin synid folder
#
cwlVersion: v1.0
class: CommandLineTool
# Needs a basecommand, so use echo as a hack
baseCommand: echo

inputs:
  - id: admin_synid
    type: string

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: update_status.json
        entry: |
          {"admin_folder": \"$(inputs.admin_synid)\"}

outputs:
  - id: json_out
    type: File
    outputBinding:
      glob: update_status.json