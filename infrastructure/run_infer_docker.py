"""Run inference synthetic docker models"""
import argparse
from functools import partial
import json
import os
import signal
import subprocess
import sys
import time

import docker
import synapseclient


def main(args):
    syn = synapseclient.Synapse(configPath=args.synapse_config)
    syn.login()

    client = docker.from_env()
    #Add docker.config file
    docker_image = args.docker_repository + "@" + args.docker_digest
    api_client = docker.APIClient(base_url='unix://var/run/docker.sock')

    #These are the volumes that you want to mount onto your docker container
    output_dir = os.path.join(os.getcwd(), "output")
    input_dir = args.input_dir
    stage = args.stage

    # These are the locations on the docker that you want your mounted volumes
    # to be + permissions in docker (ro, rw)
    # It has to be in this format '/output:rw'
    mounted_volumes = {input_dir:'/infer:ro',
                       output_dir:'/output:z'}

    #All mounted volumes here in a list
    all_volumes = [input_dir, output_dir]
    #Mount volumes
    volumes = {}
    for vol in all_volumes:
        volumes[vol] = {'bind': mounted_volumes[vol].split(":")[0],
                        'mode': mounted_volumes[vol].split(":")[1]}

    #Look for if the container exists already, if so, reconnect
    container = None
    errors = None
    for cont in client.containers.list(all=True):
        if args.submissionid in cont.name:
            #Must remove container if the container wasn't killed properly
            if cont.status == "exited":
                cont.remove()
            else:
                container = cont
    # If the container doesn't exist, make sure to run the docker image
    if container is None:
        #Run as detached, logs will stream below
        try:
            container = client.containers.run(docker_image,
                                              detach=True, volumes=volumes,
                                              name=args.submissionid,
                                              network_disabled=True,
                                              mem_limit='70g', stderr=True)

        except docker.errors.APIError as err:
            cont = client.containers.get(args.submissionid)
            cont.remove()
            errors = str(err) + "\n"

    #Create the logfile
    log_filename = args.submissionid + "_" + str(stage) + "_log.txt"
    open(log_filename, 'w').close()

    # If the container doesn't exist, there are no logs to write out and no
    # container to remove
    if container is not None:
        # Check if container is still running
        while container in client.containers.list():
            log_text = container.logs()
            with open(log_filename, 'w') as log_file:
                log_file.write(log_text)
            statinfo = os.stat(log_filename)
            # if statinfo.st_size > 0 and statinfo.st_size/1000.0 <= 50:
            if statinfo.st_size > 0:
                ent = synapseclient.File(log_filename, parent=args.parentid)
                try:
                    # syn.store(ent)
                    print("don't store")
                except synapseclient.exceptions.SynapseHTTPError:
                    pass
                time.sleep(60)
        # Must run again to make sure all the logs are captured
        log_text = container.logs()
        with open(log_filename, 'w') as log_file:
            log_file.write(log_text)

        subprocess.check_call(["docker", "cp", os.path.abspath(log_filename),
                               "logging:/logs/" + str(args.submissionid) + "/"])
        statinfo = os.stat(log_filename)
        # Only store log file if > 0 bytes
        if statinfo.st_size > 0: # and statinfo.st_size/1000.0 <= 50
            ent = synapseclient.File(log_filename, parent=args.parentid)
            try:
                # syn.store(ent)
                print("dont store")
            except synapseclient.exceptions.SynapseHTTPError:
                pass
        # Collect runtime
        inspection = api_client.inspect_container(container.name)
        inspection_path = str(args.submissionid) + "_" + str(stage) + "_inspection.txt"
        with open(inspection_path, "w") as inspection_output:
            json.dump(inspection, inspection_output, indent=4)

        subprocess.check_call(["docker", "cp", os.path.abspath(inspection_path),
                               "logging:/logs/" + str(args.submissionid) + "/"])

        #Remove container and image after being done
        container.remove()

    statinfo = os.stat(log_filename)
    if statinfo.st_size == 0:
        with open(log_filename, 'w') as log_file:
            if errors is not None:
                log_file.write(errors)
            else:
                log_file.write("No Logs")
        ent = synapseclient.File(log_filename, parent=args.parentid)
        try:
            # syn.store(ent)
            print("don't store")
        except synapseclient.exceptions.SynapseHTTPError:
            pass

    #Try to remove the image
    try:
        client.images.remove(docker_image, force=True)
    except Exception:
        print("Unable to remove image")

    output_folder = os.listdir(output_dir)
    if not output_folder:
        raise Exception("No 'predictions.csv' file written to /output, "
                        "please check inference docker")
    elif "predictions.csv" not in output_folder:
        raise Exception("No 'predictions.csv' file written to /output, "
                        "please check inference docker")
    else:
        subprocess.check_call(["docker", "cp", os.path.join(output_dir,  "predictions.csv"),
                               "logging:/logs/" + str(args.submissionid) + "/" + str(stage) + "_predictions.csv"])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--submissionid", required=True,
                        help="Submission Id")
    parser.add_argument("-p", "--docker_repository", required=True,
                        help="Docker Repository")
    parser.add_argument("-d", "--docker_digest", required=True,
                        help="Docker Digest")
    parser.add_argument("-i", "--input_dir", required=True,
                        help="Input Directory")
    parser.add_argument("-c", "--synapse_config", required=True,
                        help="credentials file")
    parser.add_argument("--parentid", required=True,
                        help="Parent Id of submitter directory")
    parser.add_argument("--stage", required=True, help="stage of pipeline")
    
    args = parser.parse_args()
    main(args)
