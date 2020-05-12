#!/usr/bin/env cwl-runner
#
# Internal workflow.  Runs on UW data
#
# Inputs:
#   submissionId: ID of the Synapse submission to process
#   adminUploadSynId: ID of a folder accessible only to the submission queue administrator
#   submitterUploadSynId: ID of a folder accessible to the submitter
#   workflowSynapseId:  ID of the Synapse entity containing a reference to the workflow file(s)
#
cwlVersion: v1.0
class: Workflow

requirements:
  - class: StepInputExpressionRequirement

inputs:
  - id: submissionId
    type: int
  - id: adminUploadSynId
    type: string
  - id: submitterUploadSynId
    type: string
  - id: workflowSynapseId
    type: string
  - id: synapseConfig
    type: File

# there are no output at the workflow engine level.  Everything is uploaded to Synapse
outputs: []

steps:

  set_permissions:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.5/set_permissions.cwl
    in:
      - id: entityid
        source: "#submitterUploadSynId"
      - id: principalid
        valueFrom: "3407544"
      - id: permissions
        valueFrom: "download"
      - id: synapse_config
        source: "#synapseConfig"
    out: []

  get_submissionid:
    run: get_linked_submissionid.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: submissionid
  
  download_goldstandard:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/synapse-client-cwl-tools/v0.1/synapse-get-tool.cwl
    in:
      - id: synapseid
        valueFrom: "syn22036993"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: filepath

  get_docker_config:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.5/get_docker_config.cwl
    in:
      - id: synapse_config
        source: "#synapseConfig"
    out: 
      - id: docker_registry
      - id: docker_authentication

  get_docker_submission:
    run: get_submission_docker.cwl
    in:
      - id: submissionid
        source: "#get_submissionid/submissionid"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: docker_repository
      - id: docker_digest
      - id: entity_id
      - id: results
      - id: admin_synid
      - id: submitter_synid

  annotate_submission_main_userid:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.5/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#get_docker_submission/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  validate_docker:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.5/validate_docker.cwl
    in:
      - id: docker_repository
        source: "#get_docker_submission/docker_repository"
      - id: docker_digest
        source: "#get_docker_submission/docker_digest"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: results
      - id: status
      - id: invalid_reasons

  annotate_docker_validation_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.5/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#validate_docker/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#annotate_submission_main_userid/finished"
    out: [finished]

  # just used for local testing
  # run_docker_infer:
  #   run: run_docker.cwl
  #   in:
  #     - id: docker_repository
  #       source: "#get_docker_submission/docker_repository"
  #     - id: docker_digest
  #       source: "#get_docker_submission/docker_digest"
  #     - id: submissionid
  #       source: "#submissionId"
  #     - id: docker_registry
  #       source: "#get_docker_config/docker_registry"
  #     - id: docker_authentication
  #       source: "#get_docker_config/docker_authentication"
  #     - id: status
  #       source: "#validate_docker/status"
  #     - id: parentid
  #       source: "#submitterUploadSynId"
  #     - id: synapse_config
  #       source: "#synapseConfig"
  #     - id: input_dir
  #       # Replace this with correct datapath
  #       valueFrom: "/Users/ThomasY/sage_projects/DREAM/covid19-challenge/infrastructure"
  #     - id: docker_script
  #       default:
  #         class: File
  #         location: "run_docker.py"
  #   out:
  #     - id: predictions
  run_docker_train:
    run: run_training_docker.cwl
    in:
      - id: docker_repository
        source: "#get_docker_submission/docker_repository"
      - id: docker_digest
        source: "#get_docker_submission/docker_digest"
      - id: submissionid
        source: "#submissionId"
      - id: docker_registry
        source: "#get_docker_config/docker_registry"
      - id: docker_authentication
        source: "#get_docker_config/docker_authentication"
      - id: status
        source: "#validate_docker/status"
      - id: parentid
        source: "#get_docker_submission/submitter_synid"
      - id: synapse_config
        source: "#synapseConfig"
      #- id: input_dir
      #  valueFrom: "uw_omop_train"
      - id: input_dir
        valueFrom: "/home/thomasyu/validation"
      - id: docker_script
        default:
          class: File
          location: "run_training_docker.py"
    out:
      - id: model
      - id: scratch
      - id: status

  run_docker_infer:
    run: run_infer_docker.cwl
    in:
      - id: docker_repository
        source: "#get_docker_submission/docker_repository"
      - id: docker_digest
        source: "#get_docker_submission/docker_digest"
      - id: submissionid
        source: "#submissionId"
      - id: docker_registry
        source: "#get_docker_config/docker_registry"
      - id: docker_authentication
        source: "#get_docker_config/docker_authentication"
      - id: status
        source: "#validate_docker/status"
      - id: parentid
        source: "#get_docker_submission/submitter_synid"
      - id: synapse_config
        source: "#synapseConfig"
      - id: model
        source: "#run_docker_train/model"
      - id: scratch
        source: "#run_docker_train/scratch"
#      - id: input_dir
#        valueFrom: "uw_omop_evaluation"
      - id: input_dir
        valueFrom: "/home/thomasyu/validation"
      - id: stage
        valueFrom: "first"
      - id: docker_script
        default:
          class: File
          location: "run_infer_docker.py"
    out:
      - id: predictions
      - id: status

  validation:
    run: validate.cwl
    in:
      - id: inputfile
        source: "#run_docker_infer/predictions"
      - id: entity_type
        valueFrom: "none"
      - id: submissionid
        source: "#submissionId"
      - id: parentid
        source: "#get_docker_submission/submitter_synid"
      - id: synapse_config
        source: "#synapseConfig"
      - id: goldstandard
        source: "#download_goldstandard/filepath"
    out:
      - id: results
      - id: status
      - id: invalid_reasons
  
  validation_email:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.5/validate_email.cwl
    in:
      - id: submissionid
        source: "#get_submissionid/submissionid"
      - id: synapse_config
        source: "#synapseConfig"
      - id: status
        source: "#validation/status"
      - id: invalid_reasons
        source: "#validation/invalid_reasons"

    out: []

  annotate_validation_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.5/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#get_submissionid/submissionid"
      - id: annotation_values
        source: "#validation/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  check_status:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.5/check_status.cwl
    in:
      - id: status
        source: "#validation/status"
      - id: previous_annotation_finished
        source: "#annotate_validation_with_output/finished"
    out: [finished]

  scoring:
    run: score.cwl
    in:
      - id: inputfile
        source: "#run_docker_infer/predictions"
      - id: goldstandard
        source: "#download_goldstandard/filepath"
      - id: submissionid
        source: "#submissionId"
      - id: status
        source: "#validation/status"
      - id: previous
        source: "#check_status/finished"
    out:
      - id: results

  score_email:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.5/score_email.cwl
    in:
      - id: submissionid
        source: "#get_submissionid/submissionid"
      - id: synapse_config
        source: "#synapseConfig"
      - id: results
        source: "#scoring/results"
    out: []

  annotate_submission_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.5/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#get_submissionid/submissionid"
      - id: annotation_values
        source: "#scoring/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]
 