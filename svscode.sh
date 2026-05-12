#!/bin/bash

# =============================================================================
# Disclaimer: 
# This script was heavily inspired by the solution by Daniel Scholz. 
# 
# I do not guarantee for correctness, if you encounter any issues, please 
# report them to me (Christian Beischl, christian.beischl@tum.de). 
# =============================================================================

# =============================================================================

RED="\e[31m"
BLUE="\e[34m"
ENDCOLOR="\e[0m"

# get directory of this script
DIR_NAME=$(dirname $(realpath "$0"))

# Settings: 
. $DIR_NAME/user.config  # source config variables from user.config

PARTITION=$VSC_PARTITION
JOBNAME=$VSC_JOBNAME
MEMORY=$VSC_MEMORY
CPUS=$VSC_CPUS
NTASKS=$VSC_NTASKS
PORT=$VSC_PORT  # Leave empty to get a random port, only works if python is specified
KEY_PATH=$VSC_KEY_PATH  # Change if you want to use a different key
OUTPUT=$VSC_OUTPUT  # Change if you want to keep the slurm output logs
ADD_SLURM_ARGS=""

TIMEOUT=$VSC_TIMEOUT  # Maximum time to wait for job to start in seconds
TIME=$VSC_TIME  # Set is to empty string if you dont want a time limit

GPU=0
QOS=""
GPU_TAG=0 
DETACHED=0

# assigning backup values if user.config is missing some variables 
# you usually don't need to do anything here!
if [ -z "$PARTITION" ]; then PARTITION="universe"; fi 
if [ -z "$JOBNAME" ]; then JOBNAME="vscode-tunnel"; fi
if [ -z "$MEMORY" ]; then MEMORY="8GB"; fi
if [ -z "$CPUS" ]; then CPUS=1; fi
if [ -z "$NTASKS" ]; then NTASKS=1; fi
if [ -z "$PORT" ]; then PORT=""; fi
if [ -z "$KEY_PATH" ]; then KEY_PATH="${HOME}/.ssh/id_rsa"; fi
if [ -z "$OUTPUT" ]; then OUTPUT="/dev/null"; fi

if [ -z "$TIMEOUT" ]; then TIMEOUT=20; fi  # Maximum time to wait for job to start in seconds
if [ -z "$TIME" ]; then TIME="8:00:00"; fi  # Set is to empty string if you dont want a time limit

# Path to python executable (only needed if PORT is not specified). 
# This is necessary since the python command may not be accessable via ssh 
# directly. 
# You can find it by running 'which python' on the server.
# PYTHON="/path/to/python
# =============================================================================

# =============================================================================
# Help menu
Help()
{
    echo -e "Simple script for running VS Code server on SLURM cluster."
    echo  # For output spacing 
    echo -e "optional arguments:" 
    echo -e "-c <NUMBER_CPUS> Set number of cpu cores for SLURM job [${BLUE}$CPUS${ENDCOLOR}]"
    echo -e "-D\t\t Run VS Code Server detached from terminal (no proxyjump possible)"
    echo -e "-g <NGPUS>\t Activate GPU support for VS Code Job." 
    echo -e "-h\t\t Shop help menu"
    echo -e "-m <MEMORY>\t Set dedicated memory for SLURM job [${BLUE}$MEMORY${ENDCOLOR}]"
    echo -e "\t\t Examples: 512MB, 8GB"
    echo -e "-n <NTASKS>\t Set ntasks for SLURM job [${BLUE}$NTASKS${ENDCOLOR}]"
    echo -e "-P <PARTITION>\t Set cluster partition for SLURM job [${BLUE}$PARTITION${ENDCOLOR}]"
    echo -e "-p <PORT>\t Set fixed port. If not specified, choose random port."
    echo -e "-q <QOS>\t Add QOS argument."
    echo -e "-S <ADD_SLURM_ARGS>"
    echo -e "-t\t\t Adds '-gpu' tag to slurm job (only needed if you want to use two"
    echo -e "\t\t different ssh configs)"
    echo 
}
# =============================================================================



while getopts 'c:Dg::m:n:P:p:q:S:t' opt; do
	case "$opt" in
		c)
            CPUS="$OPTARG"
            ;;
        D)
            DETACHED=1
            ;;
        g)
            GPU="$OPTARG"
            ;;
        h)  
            Help 
            exit
            ;;
        m)
            MEMORY="$OPTARG"
            ;;
        n)
            NTASKS="$OPTARG"
            ;;
        P)
            PARTITION="$OPTARG"
            ;; 
        p)
            PORT="$OPTARG"
            ;; 
        q) 
            QOS="$OPTARG"
            ;;
        S)
            ADD_SLURM_ARGS="$OPTARG"
            ;;
        t)  
            GPU_TAG=1
            ;;
        ?) 
            echo "Incorrect argument $opt"
            Help 
            exit
    esac
done

if [ $GPU -eq 1 ] && [ $GPU_TAG -eq 1 ]; then 
    JOBNAME="${JOBNAME}-gpu"
fi

# Constructing SLURM arguments
SLURM_ARGS="--partition=$PARTITION"  # Select node partition
SLURM_ARGS="$SLURM_ARGS --job-name=$JOBNAME"  # Set SLURM job name
SLURM_ARGS="$SLURM_ARGS --mem=$MEMORY"  # Set amount of memory to reserve
SLURM_ARGS="$SLURM_ARGS --cpus-per-task=$CPUS"  # Number of cpu cores
SLURM_ARGS="$SLURM_ARGS --ntasks-per-node=$NTASKS"  
SLURM_ARGS="$SLURM_ARGS --output=$OUTPUT"  # Set output file
if [ -n "$TIME" ]; then
    SLURM_ARGS="$SLURM_ARGS --time=$TIME"
fi
if [ $GPU -gt 0 ]; then
    SLURM_ARGS="$SLURM_ARGS --gres=gpu:$GPU"  # Add gpu support to SLURM job
fi
if [ -n "$QOS" ]; then 
    echo "using QOS: $QOS"
    SLURM_ARGS="$SLURM_ARGS --qos=$QOS"
fi 
if [ -n "$ADD_SLURM_ARGS" ]; then 
    echo "additional SLURM arguments: $ADD_SLURM_ARGS"
    SLURM_ARGS="$SLURM_ARGS $ADD_SLURM_ARGS"
fi

# if no port is specified, get unused port: 
if [ -z "$PORT" ]; then
    PORT=$($PYTHON -c "import socket; sock = socket.socket(); sock.bind(('', 0)); print(sock.getsockname()[1]);") 
fi

# Adding selected port as comment to reconnect to running sshd 
SLURM_ARGS="$SLURM_ARGS --comment=$PORT"

# Check if job is already running 
if [ -z "$(squeue --me --name=$JOBNAME -h -O nodelist --states="R")" ]; then
    # If no job is currently running or pending, start one 
    if [ -z "$(squeue --me --name=$JOBNAME -h -O nodelist --states="R,PD")" ]; then
        sbatch $SLURM_ARGS --wrap="/usr/sbin/sshd -D -p $PORT -f /dev/null -h $KEY_PATH"
    fi
    # Wait for $TIMEOUT seconds at most, check every second if job is running.
    n=0  # counter for seconds
    echo "Waiting for max $TIMEOUT seconds for job $JOBNAME to start..."
    until [ "$n" -ge $TIMEOUT ]
    do
        # if job is running, break loop
        [ -z "$(squeue --me --name=$JOBNAME -h -O nodelist --states=R)" ] || break 
        # else, wait 1 second
        n=$((n+1)) 
        sleep 1
    done
    # after loop, check if job is running
    # if not, exit with error
    if [ -z "$(squeue --me --name=$JOBNAME -h -O nodelist --states=R)" ]; then
        echo "Job $JOBNAME not running"
        exit 1
    else
        echo "Job $JOBNAME running"
    fi
else
    echo "Job $JOBNAME already running"

    # if job is already running, get selected port from comment
    PORT=$(squeue --me --name=$JOBNAME -h -O comment --states=R)
fi

if [ $DETACHED -eq 0 ]; then 
    echo -e "${RED}Warning: quitting with Ctrl-c will not stop the VS Code SLURM Job!${ENDCOLOR}"
    nc $(squeue --me --name=$JOBNAME -h -O nodelist --states=R -h) $PORT
fi
