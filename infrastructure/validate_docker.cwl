#!/usr/bin/env cwl-runner
#
# Validates Docker Submission
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v2.0.0

inputs:
  - id: docker_repository
    type: string?
  - id: docker_digest
    type: string?
  - id: synapse_config
    type: File

arguments:
  - valueFrom: validate_docker.py
  - valueFrom: $(inputs.docker_repository)
    prefix: -p
  - valueFrom: $(inputs.docker_digest)
    prefix: -d
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: results.json
    prefix: -r

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: validate_docker.py
        entry: |
          #!/usr/bin/env python
          import synapseclient
          import argparse
          import os
          import json
          import base64
          import requests
          parser = argparse.ArgumentParser()
          parser.add_argument("-p", "--docker_repository", help="Submission File")
          parser.add_argument("-d", "--docker_digest", help="Submission File")
          parser.add_argument("-r", "--results", required=True, help="validation results")
          parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
          args = parser.parse_args()

          def get_bearer_token_url(docker_request_url, user, password):
            initial_request = requests.get(docker_request_url)
            auth_headers = initial_request.headers['Www-Authenticate'].replace('"','').split(",")
            for head in auth_headers:
              if head.startswith("Bearer realm="):
                bearer_realm = head.split('Bearer realm=')[1]
              elif head.startswith('service='):
                service = head.split('service=')[1]
              elif head.startswith('scope='):
                scope = head.split('scope=')[1]
            return("{0}?service={1}&scope={2}".format(bearer_realm,service,scope))

          def get_auth_token(docker_request_url, user, password):
            bearer_token_url = get_bearer_token_url(docker_request_url, user, password)
            auth_string = user + ":" + password 
            auth = base64.b64encode(auth_string.encode()).decode()
            bearer_token_request = requests.get(bearer_token_url,
              headers={'Authorization': 'Basic %s' % auth})
            return(bearer_token_request.json()['token'])

          invalid_reasons = []
          labels = {}
          # Submission must be a Docker image, not Project/Folder/File
          if args.docker_repository and args.docker_digest:

            #Must read in credentials (username and password)
            config = synapseclient.Synapse().getConfigFile(configPath=args.synapse_config)
            authen = dict(config.items("authentication"))
            if authen.get("username") is None and authen.get("password") is None:
              raise Exception('Config file must have username and password')
            docker_repo = args.docker_repository.replace("docker.synapse.org/","")
            docker_digest = args.docker_digest
            index_endpoint = 'https://docker.synapse.org'

            #Check if docker is able to be pulled
            docker_request_url = '{0}/v2/{1}/manifests/{2}'.format(index_endpoint, docker_repo, docker_digest)
            token = get_auth_token(docker_request_url, authen['username'], authen['password'])

            resp = requests.get(docker_request_url, headers={'Authorization': 'Bearer %s' % token})
            if resp.status_code != 200:
              invalid_reasons.append("Docker image + sha digest must exist.  You submitted %s@%s" % (args.docker_repository,args.docker_digest))

            #Must check docker image size
            #Synapse docker registry
            docker_size = sum([layer['size'] for layer in resp.json()['layers']])
            if docker_size/1000000000.0 >= 1000:
              invalid_reasons.append("Docker container must be less than a teribyte")
            

            blob_request_url = '{0}/v2/{1}/blobs/{2}'.format(index_endpoint, docker_repo, resp.json()['config']['digest'])
            blob_resp = requests.get(blob_request_url, headers={'Authorization': 'Bearer %s' % token})
            labels = blob_resp.json()['container_config']['Labels']
            required_labels = {'challenge', 'description', 'ranked_features', 'references'}
            # features = ['age', 'gender', 'cough', 'fever', 'fatigue']

            if labels and required_labels.issubset(labels.keys()):
              if labels['challenge'] != "covid19":
                invalid_reasons.append("challenge LABEL must be covid19")
              if labels['description'] == '':
                invalid_reasons.append("description LABEL can't be empty string")
              if labels['ranked_features'].split(",")[0] == '':
                invalid_reasons.append("ranked_features LABEL can't be empty string")
              for label in required_labels:
                if len(labels[label]) > 500:
                  invalid_reasons.append(f"{label} LABEL must be smaller than 500 characters")
              training = labels.get("enable_training")
              if training is not None:
                if training not in [True, False]:
                  invalid_reasons.append("If you specify enable_training, it must be true or false.")
              else:
                labels['enable_training'] = False
            else:
              labels = {}
              invalid_reasons.append("Dockerfile must contain these Dockerfile LABELs: {}".format(",".join(required_labels)))
          else:
            invalid_reasons.append("Submission must be a Docker image, not Project/Folder/File. Please visit 'Docker Submission' for more information.")
        
          # Don't store labels if invalid
          if invalid_reasons:
            status = "INVALID"
            labels = {}
          else:
            status = "EVALUATION_IN_PRORGRESS"

          result = {'submission_errors':"\n".join(invalid_reasons),
                    'submission_status':status}
          result.update(labels)
          if labels:
            features = ", ".join(labels['ranked_features'].split(","))
            references = ", ".join(labels['references'].split(","))
            result['detailed_information'] = (
              "<details>\n\n"
              "<summary>Expand for details</summary>\n\n"
              f"**Description:** {labels['description']}\n"
              f"**Ranked features:** {features}\n"
              f"**References:** {references}\n\n"
              "</details>")
          else:
            result['detailed_information'] = 'No Details'
          with open(args.results, 'w') as o:
            o.write(json.dumps(result))

outputs:

  - id: results
    type: File
    outputBinding:
      glob: results.json   

  - id: status
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['submission_status'])

  - id: invalid_reasons
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['submission_errors'])

  - id: enable_training
    type: boolean
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['enable_training'])
