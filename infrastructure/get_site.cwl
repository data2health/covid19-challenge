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
  - id: dataset_name
    type: string
  - id: train_dataset_version
    type: string
  - id: infer_dataset_version
    type: string

expression: |

  ${
    if (inputs.evaluation_id == "9614494" || inputs.evaluation_id == "9614451"){
      return {site: "UW",
              dataset_name: "uw_omop_covid_q1",
              train_dataset_version: "05-06-2020",
              infer_dataset_version: "05-06-2020"};
    } else {
      throw 'no dataset goldstandard';
    }
  }
