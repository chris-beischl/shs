#!/bin/bash

# =============================================================================
# Disclaimer:  
# I do not guarantee for correctness, if you encounter any issues, please 
# report them to me (Christian Beischl, christian.beischl@tum.de). 
# =============================================================================

# =============================================================================
# How to use this script:
#
# 1. Start script with ./sjupyter.sh or sjupyter (if added to bashrc) 
# 2. After the script started, it will display both the URL and a argument of 
#    shape '-L <PORT>:localhost:<PORT>'.
#    Copy this argument and use it in a new terminal to establish another ssh
#    connection to the server with portforwarding. 
# 
# The Jupyter server can now be accessed from your local machine using the URL
# displayed by the script.
# 
# Note: Manually adding the portforwarding argument can be ommited if you hard-
#       code the portforwarding in your local ~/.ssh/config file and in this 
#       script (Within Default Setting).
#       E.g. adding something like: LocalForward <PORT> localhost:<PORT> 
# 
# -----------------------------------------------------------------------------
# [Optional] How to connect to Jupyter server in VS Code?"
# 
# 1. Open the .ipynb file in VS Code you want to work on.
# 2. Click on 'Select Kernel' in the top right corner
# 5. Select 'Select Another Kernel...'.
# 4. Select 'Existing Server' and paste the URL from above
# 5. Choose Server display name, the default 'localhost' is fine
# 6. Select python kernel version.
#
# =============================================================================

# =============================================================================
# Colors for highlighting important information
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
ORANGE="\e[40m"
ENDCOLOR="\e[0m"

HIGHLIGHT=$GREEN

# get directory of file
SCRIPT=$(realpath "$0")
SCRIPT_DIR=$(dirname $SCRIPT)

echo "running $SCRIPT in $(pwd)"

# Settings: 
. $SCRIPT_DIR/user.config  # source config variables from user.config 

PARTITION=$JUPYTER_PARTITION
JOBNAME=$JUPYTER_JOBNAME
MEMORY=$JUPYTER_MEMORY
CPUS=$JUPYTER_CPUS
NTASKS=$JUPYTER_NTASKS
PORT=$JUPYTER_PORT
TOKEN=$JUPYTER_TOKEN
GPU=$JUPYTER_GPU

TIME=$JUPYTER_TIME  # Set is to empty string if you dont want a time limit

PRINT_RUNNING=0
DETACHED=0

# Default Settings, overwrite if variable is empty: 
# If you use a different jupyter installation, set this command accordingly 
if [ -z "$JUPYTER_COMMAND" ]; then JUPYTER_CMD="jupyter notebook"; fi

if [ -z "$PARTITION" ]; then PARTITION=universe; fi 
if [ -z "$JOBNAME" ]; then JOBNAME=jupyter; fi 
if [ -z "$MEMORY" ]; then MEMORY=8GB; fi
if [ -z "$CPUS" ]; then CPUS=1; fi
if [ -z "$NTASKS" ]; then NTASKS=1; fi
if [ -z "$PORT" ]; then PORT=""; fi
if [ -z "$TOKEN" ]; then TOKEN=${USER}_jupyter_server; fi
if [ -z "$GPU" ]; then GPU=0; fi

if [ -z "$TIME" ]; then TIME="8:00:00"; fi  # Set is to empty string if you dont want a time limit

if [ -z "$VSC_JOBNAME" ]; then VSC_JOBNAME=vscode-tunnel; fi
# =============================================================================

# =============================================================================
# Help menu
Help()
{
    echo -e "Simple script for running jupyter notebook on SLURM cluster."
    echo  # For output spacing 
    echo -e "optional arguments:" 
    echo -e "-c <NUMBER_CPUS> Set number of cpu cores for SLURM job [${BLUE}$CPUS${ENDCOLOR}]"
    echo -e "-D\t\t Run Jupyter server detached from terminal (using sbatch)"
    echo -e "-g\t\t Activate GPU support für notebook"
    echo -e "-h\t\t Shop help menu"
    echo -e "-j <JOBNAME>\t Set SLURM jobname [${BLUE}$JOBNAME${ENDCOLOR}]"
    echo -e "-m <MEMORY>\t Set dedicated memory for SLURM job [${BLUE}$MEMORY${ENDCOLOR}]"
    echo -e "\t\t Examples: 512MB, 8GB"
    echo -e "-n <NTASKS>\t Set ntasks for SLURM job [${BLUE}$NTASKS${ENDCOLOR}]"
    echo -e "-p <PARTITION>\t Set cluster partition for SLURM job [${BLUE}$PARTITION${ENDCOLOR}]"
    echo -e "-P <PORT>\t Set fixed port. If not specified, choose random port."
    echo -e "-R\t\t Print all your running jobs with their respective addresses with JOBNAME"
    echo -e "-t <TOKEN>\t Set specific token for the Jupyter Notebook server [${BLUE}$TOKEN${ENDCOLOR}]"
    echo 
}
# =============================================================================

# =============================================================================
# Parse arguments
while getopts 'c:Dghj:m:n:p:P:Rt:' opt; do
	case "$opt" in
		c)
            CPUS="$OPTARG"
            ;;
        D)  DETACHED=1
            ;;
        g)
            GPU=1
            ;;
        h)  
            Help
            exit
            ;;
        j)
            JOBNAME="$OPTARG"
            ;;
        m) 
            MEMORY="$OPTARG"
            ;;
        n)
            NTASKS="$OPTARG"
            ;;
        p)
            PARTITION="$OPTARG"
            ;; 
        P)
            PORT="$OPTARG"
            ;; 

        R)  PRINT_RUNNING=1
            ;;
        t)  
            TOKEN="$OPTARG"
            ;;
        ?) 
            Help
            exit
    esac
done
# =============================================================================

# Print running servers
if [ $PRINT_RUNNING -eq 1 ]; then 
    JOBS=$(squeue --me -h --name=$JOBNAME -o "%t|%b|%k") 
    LEN_STATUS=$(squeue --me --name=$JOBNAME -o "%t" | wc -L)
    LEN_TRES=$(squeue --me --name=$JOBNAME -o "%b" | wc -L)
    LEN_COMMENT=$(squeue --me --name=$JOBNAME -o "%k" | wc -L)
    FORMAT="%.${LEN_STATUS}t %.${LEN_TRES}b %.${LEN_COMMENT}k"
    JOBS=$(squeue --me --name=$JOBNAME -o "$FORMAT")

    if [[ -z "$JOBS" ]]; then
        echo "No servers with jobname '$JOBNAME' found!"
            exit 0
    fi
    
    INDEX=0
    while IFS= read -r LINE; do
        if [ $INDEX -eq 0 ]; then
            echo -e "${YELLOW}$LINE URL${ENDCOLOR}"
        else
            PORT=$(echo $LINE | tr -s " " | cut -d ' ' -f 3)
            URL="http://localhost:$PORT/?token=$TOKEN"
            echo -e "$LINE ${HIGHLIGHT}$URL${ENDCOLOR}" 
        fi
        INDEX+=1
    done <<< "$JOBS"

    exit 0
fi


# if no port is specified, get unused port: 
if [ -z "$PORT" ]; then
    PORT=$(python -c "import socket; sock = socket.socket(); sock.bind(('', 0)); print(sock.getsockname()[1]);") 
fi

# Output settings
echo Settings: 
echo -e "| partition: ${BLUE}$PARTITION${ENDCOLOR}" 
echo -e "| jobname: ${BLUE}$JOBNAME${ENDCOLOR}" 
echo -e "| memory: ${BLUE}$MEMORY${ENDCOLOR}"
echo -e "| cpus-per-task: ${BLUE}$CPUS${ENDCOLOR}"
echo -e "| ntasks: ${BLUE}$NTASKS${ENDCOLOR}"
if [ $GPU -eq 1 ]; then 
    echo -e "| gpu-support: ${GREEN}True${ENDCOLOR}"
else 
    echo -e "| gpu-support: ${RED}False${ENDCOLOR}"
fi
echo -e "| token: ${BLUE}$TOKEN${ENDCOLOR}"
echo -e "| port: ${BLUE}$PORT${ENDCOLOR}" 
echo  # For output spacing 

# =============================================================================
# Reverse portforwarding

# Constructing SSH command for reverse portforwarding to login node
SSH_CMD="ssh -N -f -R $PORT:localhost:$PORT $USER@$(hostname)"
SSH_CMD="echo Start reverse portforwarding from \"\$(hostname)\" to \"$(hostname)\".; $SSH_CMD"

# Check if a VSCODE tunnel job is running
VSCODE_NODE=$(squeue -u $USER -n $VSC_JOBNAME -h -o "%N")  # Output is only the node name
if [ -n "$VSCODE_NODE" ]; then
    VSCODE_PORT=$(squeue -u $USER -n $VSC_JOBNAME -h -o "%k")
    echo "Found active vscode-tunnel job on node \"$VSCODE_NODE\", Port: $VSCODE_PORT"
else
    echo "No active vscode-tunnel job found. Running Jupyter only with portforwarding to \"$(hostname)\"."
fi
echo  #spaciing 

# Reverse portforwarding to vscode node, if available
if [ -n "$VSCODE_NODE" ]; then
    # Constructing SSH command for reverse portforwarding to vscode-tunnel node
    SSH_PORTFWD_VSCODE_NODE="ssh -p $VSCODE_PORT -o StrictHostKeyChecking=no -N -f -R $PORT:localhost:$PORT $USER@$VSCODE_NODE"
    # Add conditional portforwarding to SSH command, only if vscode-tunnel node is different from jupyter-node
    # Also add a message to the output
    SSH_CMD="$SSH_CMD && if [[ $VSCODE_NODE != \$(hostname) ]]; then $SSH_PORTFWD_VSCODE_NODE; echo Start reverse portforwarding from \"\$(hostname)\" to \"$VSCODE_NODE\".; else echo Both VSCode and Jupyter running on \"\$(hostname)\", no additional portforwarding needed.; fi"
fi 

# Adding output padding
SSH_CMD="echo; $SSH_CMD; echo"
# =============================================================================

# =============================================================================
# Constructing SLURM arguments
SLURM_ARGS="--partition=$PARTITION"  # Select node partition
SLURM_ARGS="$SLURM_ARGS --job-name=$JOBNAME"  # Set SLURM job name
SLURM_ARGS="$SLURM_ARGS --mem=$MEMORY"  # Set amount of memory to reserve
SLURM_ARGS="$SLURM_ARGS --cpus-per-task=$CPUS"  # Number of cpu cores
if [ $GPU -eq 1 ]; then
    SLURM_ARGS="$SLURM_ARGS --gres=gpu:1"  # Add gpu support to SLURM job
fi
SLURM_ARGS="$SLURM_ARGS --ntasks-per-node=$NTASKS"  

if [ -n "$TIME" ]; then
    SLURM_ARGS="$SLURM_ARGS --time=$TIME"
fi

# Showing port in slurm - to reconnect
SLURM_ARGS="$SLURM_ARGS --comment=$PORT"
# =============================================================================

# Constructing Jupyter arguments
JUPYTER_ARGS="--no-browser --port $PORT --NotebookApp.token=$TOKEN"

# Constructing Info command: 
INFO_CMD="echo; echo Jupyter Notebook Server is running on node: \"\$(hostname)\", Port: $PORT" 

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ How to use this? ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
echo -e "1. Open a second SSH connection on your client with following option set:"
echo -e "   ${RED}This step is NOT necessary if you use VS Code with the vscode-tunnel job{ENDCOLOR}"
echo 
echo -e "\t\t ${HIGHLIGHT}-L ${PORT}:localhost:${PORT}${ENDCOLOR}" 
echo
echo -e "2. Connect to the Jupyter Notebook Server with the following link:"
echo
echo -e "\t ${HIGHLIGHT}http://localhost:${PORT}/?token=${TOKEN}${ENDCOLOR}"
echo 
echo
echo -e "[${YELLOW}Optional${ENDCOLOR}] How to connect to Jupyter server in VS Code?"
echo 
echo -e "1. Open the .ipynb file in VS Code you want to work on." 
echo -e "2. Click on 'Select Kernel' in the top right corner."
echo -e "5. Select 'Select Another Kernel...'." 
echo -e "4. Select 'Existing Server' and paste the URL from above."
echo -e "5. Choose Server display name, the default 'localhost' is fine."
echo -e "6. Select python kernel version." 
echo 
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo  
echo
echo "~~~~~~~~~~~ Running Jupyter Notebook on SLURM with following command ~~~~~~~~~~~"
if [ $DETACHED -eq 1 ]; then
    echo "sbatch $SLURM_ARGS --wrap=\"bash -c \\\"{ $INFO_CMD && $SSH_CMD && $JUPYTER_CMD $JUPYTER_ARGS; }i\\\"\"" 
else
    echo "srun $SLURM_ARGS bash -c \"{ $INFO_CMD && $SSH_CMD && $JUPYTER_CMD $JUPYTER_ARGS; }\""
fi 
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo

# Running the jupyter notebook on slurm with all arguments
if [ $DETACHED -eq 1 ]; then 
    sbatch $SLURM_ARGS --wrap="bash -c \"{ $INFO_CMD && $SSH_CMD && $JUPYTER_CMD $JUPYTER_ARGS; }\""
else
    srun $SLURM_ARGS bash -c "{ $INFO_CMD && $SSH_CMD && $JUPYTER_CMD $JUPYTER_ARGS; }"
fi
