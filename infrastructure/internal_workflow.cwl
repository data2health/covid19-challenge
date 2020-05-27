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
      - id: evaluation_id
      - id: results

  get_dataset_info:
    run: get_dataset.cwl
    in:
      - id: queueid
        source: "#get_submissionid/evaluation_id"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: site
      - id: train_volume
      - id: infer_volume
      - id: results

  modify_dataset_annotations:
    run: modify_annotations.cwl
    in:
      - id: inputjson
        source: "#get_dataset_info/results"
      - id: site
        source: "#get_dataset_info/site"
    out: [results]

  annotate_dataset_version:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.5/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#get_submissionid/submissionid"
      - id: annotation_values
        source: "#modify_dataset_annotations/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  annotate_internal_dataset_version:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.5/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#get_dataset_info/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  download_goldstandard:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/synapse-client-cwl-tools/v0.1/synapse-get-tool.cwl
    in:
      - id: synapseid
        valueFrom: "syn22043503"
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

  # validate_docker:
  #   run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.5/validate_docker.cwl
  #   in:
  #     - id: docker_repository
  #       source: "#get_docker_submission/docker_repository"
  #     - id: docker_digest
  #       source: "#get_docker_submission/docker_digest"
  #     - id: synapse_config
  #       source: "#synapseConfig"
  #   out:
  #     - id: results
  #     - id: status
  #     - id: invalid_reasons

  # annotate_docker_validation_with_output:
  #   run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.5/annotate_submission.cwl
  #   in:
  #     - id: submissionid
  #       source: "#submissionId"
  #     - id: annotation_values
  #       source: "#validate_docker/results"
  #     - id: to_public
  #       default: true
  #     - id: force
  #       default: true
  #     - id: synapse_config
  #       source: "#synapseConfig"
  #     - id: previous_annotation_finished
  #       source: "#annotate_submission_main_userid/finished"
  #   out: [finished]

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
      - id: parentid
        source: "#get_docker_submission/submitter_synid"
      - id: synapse_config
        source: "#synapseConfig"
      - id: input_dir
        source: "#get_dataset_info/train_volume"
      - id: docker_script
        default:
          class: File
          location: "run_training_docker.py"
    out:
      - id: model
      - id: scratch

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
      - id: parentid
        source: "#get_docker_submission/submitter_synid"
      - id: synapse_config
        source: "#synapseConfig"
      - id: model
        source: "#run_docker_train/model"
      - id: scratch
        source: "#run_docker_train/scratch"
      - id: input_dir
        source: "#get_dataset_info/infer_volume"
      - id: stage
        valueFrom: "first"
      - id: docker_script
        default:
          class: File
          location: "run_infer_docker.py"
    out:
      - id: predictions

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
    out: [finished]

  # Add tool to revise scores to add extra dataset queue
  modify_validation_annotations:
    run: modify_annotations.cwl
    in:
      - id: inputjson
        source: "#validation/results"
      - id: site
        source: "#get_dataset_info/site"
    out: [results]

  annotate_main_submission_with_validation:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.5/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#get_submissionid/submissionid"
      - id: annotation_values
        source: "#modify_validation_annotations/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  annotate_validation_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.5/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
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
        source: "#annotate_main_submission_with_validation/finished"
      - id: previous_email_finished
        source: "#validation_email/finished"
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
      - id: private_annotations
        default: ['submission_status']
    out: []

  # Add tool to revise scores to add extra dataset queue
  modify_annotations:
    run: modify_annotations.cwl
    in:
      - id: inputjson
        source: "#scoring/results"
      - id: site
        source: "#get_dataset_info/site"
    out: [results]

  annotate_main_submission_with_scores:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.5/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#get_submissionid/submissionid"
      - id: annotation_values
        source: "#modify_annotations/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  # annotate internal submission with scores
  annotate_submission_with_scores:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.5/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#scoring/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]
 
