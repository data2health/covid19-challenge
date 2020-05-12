#!/usr/bin/env cwl-runner
#
# Get site and dataset version
#
cwlVersion: v1.0
class: ExpressionTool

inputs:
  - id: evaluation_id
    type: string

requirements:
  - class: InlineJavascriptRequirement
     
outputs:
  - id: site
    type: string
  - id: dataset_version
    type: string

expression: |

  ${
    if (inputs.evaluation_id == "9614494" or inputs.evaluation_id == "9614451"){
      return {site: "UW", dataset_version: "version1"};
    } else {
      throw 'no dataset goldstandard';
    }
  }
