#!/bin/bash

DIR_NAME=$(dirname $(realpath "$0"))
JUPYTER_NAME="sjupyter.sh"
VSCODE_NAME="svscode.sh"
SCANCEL_NAME="sc.sh"

SCRIPT_NAMES=( "$JUPYTER_NAME" "$VSCODE_NAME" "$SCANCEL_NAME" )

CONFIG="$DIR_NAME/user.config"
BASHRC="$HOME/.bashrc"

INPUT=""
DO_CONFIG='yes'

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
ENDCOLOR="\e[0m"
NORMAL="\e[0m"
BOLD="\e[1m"

HIGHLIGHT=$BOLD

PARTITION="universe"
PYTHON="$(which python)"

# =============================================================================
# Jupyter Server Default Config

# Jupyter command
JUPYTER_CMD="jupyter notebook"

JUPYTER_PARTITION=$PARTITION
JUPYTER_JOBNAME="sjupyter"
JUPYTER_MEMORY=16GB
JUPYTER_CPUS=4
JUPYTER_NTASKS=1
JUPYTER_PORT=""  # if set, will always use same port if not overwritten by CLI
JUPYTER_TOKEN=${USER}_jupyter_server
JUPYTER_TIME="8:00:00"
GPU=0
# =============================================================================

# =============================================================================
# VSCode Tunnel Default Config

VSC_PARTITION=$PARTITION
VSC_JOBNAME="vscode-tunnel"
VSC_MEMORY=8GB
VSC_CPUS=4
VSC_NTASKS=1
VSC_PORT=""  # Leave empty to get a random port, only works if python is specified
VSC_KEY_PATH="${HOME}/.ssh/id_rsa"  # Change if you want to use a different key
VSC_OUTPUT="/dev/null"  # Change if you want to keep the slurm output logs

VSC_TIMEOUT=30  # Maximum time to wait for job to start in seconds
VSC_TIME="8:00:00"  # Set is to empty string if you dont want a time limit
# =============================================================================

yes_no() {
    PROMPT=$1
    while true; do 
        read -p "$PROMPT (yes/no): " yn_func
        case $yn_func in
            [yY] ) yn_func='yes'
                break;;
        yes ) break;;
        [nN] ) yn_func='no';
            break;;
        no ) break;;
        * ) ;;
        esac
    done 

    echo $yn_func
}


echo "Welcome to shs installer" 
echo
echo "This script will guide you through the installation process of shs"

# =============================================================================
# Configuration

# Check if user.config already exists
if [ -f "$CONFIG" ]; then 
echo -e "${RED}Warning: $CONFIG already exists!${ENDCOLOR}"
    yn=$(yes_no "Do you want to reconfigure?")
    if [ "$yn" == "no" ]; then
        DO_CONFIG='no'
    fi
fi 

# Start configuration
if [ $DO_CONFIG == 'yes' ]; then 
    echo 
    echo 
    echo "# ============================================================================="
    echo "Starting configuration"
    echo
    echo -e "Default values will be shown in brackets and highlighted in ${BLUE}blue${ENDCOLOR}."
    echo -e "Press enter to keep the default value." 
    echo 
    echo "# General Configurations ======================================================"
    echo -e "Default SLURM partition [${BLUE}$PARTITION${ENDCOLOR}]: " 
    read -p "> " INPUT
    if [ -n "$INPUT" ]; then PARTITION=$INPUT; fi
    echo -e "Default python path: [${BLUE}$PYTHON${ENDCOLOR}]: " 
    read -p "> " INPUT
    if [ -n "$INPUT" ]; then PYTHON=$INPUT; fi
    echo "# ============================================================================="
    echo 

    echo
    echo "# Jupyter Configurations ======================================================"
    echo "# All configurations can later be changed in user.config or using the CLI" 
    echo
    echo -e "Jupyter command [${BLUE}$JUPYTER_CMD${ENDCOLOR}]: " 
    read -p "> " INPUT
    if [ -n "$INPUT" ]; then JUPYTER_CMD=$INPUT; fi
    echo -e "Jupyter SLURM partition [${BLUE}$PARTITION${ENDCOLOR}]: " 
    read -p "> " INPUT
    if [ -n "$INPUT" ]; then JUPYTER_PARTITION=$INPUT; else JUPYTER_PARTITION=$PARTITION; fi
    echo -e "Jupyter jobname [${BLUE}$JUPYTER_JOBNAME${ENDCOLOR}]: " 
    read -p "> " INPUT
    if [ -n "$INPUT" ]; then JUPYTER_JOBNAME=$INPUT; fi
    echo -e "Jupyter memory [${BLUE}$JUPYTER_MEMORY${ENDCOLOR}]: " 
    read -p "> " INPUT
    if [ -n "$INPUT" ]; then JUPYTER_MEMORY=$INPUT; fi
    echo -e "Jupyter CPUs [${BLUE}$JUPYTER_CPUS${ENDCOLOR}]: " 
    read -p "> " INPUT
    if [ -n "$INPUT" ]; then JUPYTER_CPUS=$INPUT; fi
    echo -e "Jupyter ntasks [${BLUE}$JUPYTER_NTASKS${ENDCOLOR}]: " 
    read -p "> " INPUT
    if [ -n "$INPUT" ]; then JUPYTER_NTASKS=$INPUT; fi
    echo -e "Jupyter port - if none is specified will automatically select free port (recommended) [${BLUE}$JUPYTER_PORT${ENDCOLOR}]: " 
    read -p "> " INPUT
    if [ -n "$INPUT" ]; then JUPYTER_PORT=$INPUT; fi
    echo -e "Jupyter Token [${BLUE}$JUPYTER_TOKEN${ENDCOLOR}]: " 
    read -p "> " INPUT
    if [ -n "$INPUT" ]; then JUPYTER_TOKEN=$INPUT; fi
    echo -e "Jupyter time limit (how long the job at most runs) [${BLUE}$JUPYTER_TIME${ENDCOLOR}]: " 
    read -p "> " INPUT
    if [ -n "$INPUT" ]; then JUPYTER_TIME=$INPUT; fi
    echo "# ============================================================================="
    echo 

    echo 
    echo "# VS Code Tunnel Configurations ================================================"
    echo "# All configurations can later be changed in the generated user.config" 
    echo
    echo -e "VSCode Tunnel SLURM partition [${BLUE}$PARTITION${ENDCOLOR}]: " 
    read -p "> " INPUT
    if [ -n "$INPUT" ]; then VSC_PARTITION=$INPUT; else VSC_PARTITION=$PARTITION; fi
    echo -e "VSCode Tunnel jobname ${BLUE}$VSC_JOBNAME${ENDCOLOR}]: " 
    read -p "> " INPUT
    if [ -n "$INPUT" ]; then VSC_JOBNAME=$INPUT; fi
    echo -e "VSCode Tunnel memory [${BLUE}$VSC_MEMORY${ENDCOLOR}]: " 
    read -p "> " INPUT
    if [ -n "$INPUT" ]; then VSC_MEMORY=$INPUT; fi
    echo -e "VSCode Tunnel CPUs [${BLUE}$VSC_CPUS${ENDCOLOR}]: " 
    read -p "> " INPUT
    if [ -n "$INPUT" ]; then VSC_CPUS=$INPUT; fi
    echo -e "VSCode Tunnel ntasks [${BLUE}$VSC_NTASKS${ENDCOLOR}]: " 
    read -p "> " INPUT
    if [ -n "$INPUT" ]; then VSC_NTASKS=$INPUT; fi
    echo -e "VSCode Tunnel ssh key path [${BLUE}$VSC_KEY_PATH${ENDCOLOR}]: " 
    read -p "> " INPUT
    if [ -n "$INPUT" ]; then VSC_KEY_PATH=$INPUT; fi
    echo -e "VSCode Tunnel output path [${BLUE}$VSC_OUTPUT${ENDCOLOR}]: " 
    read -p "> " INPUT
    if [ -n "$INPUT" ]; then VSC_OUTPUT=$INPUT; fi
    echo -e "VSCode Tunnel timeout (max time in seconds to wait for the job to run) [${BLUE}$VSC_TIMEOUT${ENDCOLOR}]: " 
    read -p "> " INPUT
    if [ -n "$INPUT" ]; then VSC_TIMEOUT=$INPUT; fi
    echo -e "VSCode Tunnel time limit (how long the job at most runs) [${BLUE}$VSC_TIME${ENDCOLOR}]: " 
    read -p "> " INPUT
    if [ -n "$INPUT" ]; then VSC_TIME=$INPUT; fi
    echo "# ============================================================================="

# Create user.config 
    echo "" > $CONFIG
    echo "# General Configurations" >> $CONFIG
    echo "PARTITION=$PARTITION" >> $CONFIG
    echo "PYTHON=$PYTHON" >> $CONFIG
    echo "" >> $CONFIG
    echo "# =============================================================================" >> $CONFIG
    echo "# Jupyter Configurations" >> $CONFIG
    echo "JUPYTER_CMD=\"$JUPYTER_CMD\"" >> $CONFIG
    echo "JUPYTER_PARTITION=$JUPYTER_PARTITION" >> $CONFIG
    echo "JUPYTER_JOBNAME=$JUPYTER_JOBNAME" >> $CONFIG
    echo "JUPYTER_MEMORY=$JUPYTER_MEMORY" >> $CONFIG
    echo "JUPYTER_CPUS=$JUPYTER_CPUS" >> $CONFIG
    echo "JUPYTER_NTASKS=$JUPYTER_NTASKS" >> $CONFIG
    echo "JUPYTER_PORT=\"$JUPYTER_PORT\"" >> $CONFIG
    echo "JUPYTER_TIME=$JUPYTER_TIME" >> $CONFIG
    echo "" >> $CONFIG
    echo "# =============================================================================" >> $CONFIG
    echo "# VSCode Tunnel Configurations" >> $CONFIG
    echo "VSC_PARTITION=$VSC_PARTITION" >> $CONFIG
    echo "VSC_JOBNAME=$VSC_JOBNAME" >> $CONFIG
    echo "VSC_MEMORY=$VSC_MEMORY" >> $CONFIG
    echo "VSC_CPUS=$VSC_CPUS" >> $CONFIG
    echo "VSC_NTASKS=$VSC_NTASKS" >> $CONFIG
    echo "VSC_PORT=\"$VSC_PORT\"" >> $CONFIG
    echo "VSC_KEY_PATH=$VSC_KEY_PATH" >> $CONFIG
    echo "VSC_OUTPUT=$VSC_OUTPUT" >> $CONFIG
    echo "VSC_TIMEOUT=$VSC_TIMEOUT" >> $CONFIG
    echo "VSC_TIME=$VSC_TIME" >> $CONFIG

    echo -e "${GREEN}Created $CONFIG.${ENDCOLOR}"
else  # Skip configuration
    echo -e "${YELLOW}Skipping configuration${ENDCOLOR}"
fi
echo 

# =============================================================================
# Execution rights 

# Check if scripts are executable
echo 
SCRIPTS_ARE_EXECUTABLE=1

for SCRIPT_NAME in "${SCRIPT_NAMES[@]}"; do
    if [ ! -f "$DIR_NAME/$SCRIPT_NAME" ]; then
        echo -e "${RED}Error: $SCRIPT_NAME not found!${ENDCOLOR}"
        echo -e "${RED}Please make sure the script is in the same directory as the installer.${ENDCOLOR}"
        exit 1
    else
        if [ ! -x "$DIR_NAME/$SCRIPT_NAME" ]; then
            SCRIPTS_ARE_EXECUTABLE=0
        fi
    fi
done

# Assign execute permissions
if [ $SCRIPTS_ARE_EXECUTABLE -eq 0 ]; then
    echo -e "Scripts are not yet executable."
    yn=$(yes_no "Assign execute permissions?")

    if [ "$yn" == "yes" ]; then
        for SCRIPT_NAME in "${SCRIPT_NAMES[@]}"; do
            chmod +x "$DIR_NAME/$SCRIPT_NAME"
        done
        echo -e "${GREEN}Assigned execute permissions to scripts${ENDCOLOR}"
    else
        echo -e "${RED}Scripts require execute permission to run. Please assign them manually or rerun script.${ENDCOLOR}"
    fi
else
    echo -e "${GREEN}Scripts are already executable.${ENDCOLOR}"
fi
echo

# =============================================================================
# Add ssh key to authorized_keys
echo
HAS_SSH_KEY=$(cat $HOME/.ssh/authorized_keys | grep "$USER@$(hostname)")
if [ -z "$HAS_SSH_KEY" ]; then
    echo "To establish ssh connections between nodes, we need to add your ssh key to the authorized_keys file."
    echo "All nodes use the same ssh key as the login node. But we need to add this key to the authorized_keys file to allow connecting from one node to another."
    yn=$(yes_no "Do you want to copy the ssh key? (requires password!)")
    if [ "$yn" == "no" ]; then
        echo -e "${RED}Warning: ssh key is required to run the scripts. Please add it manually or rerun script!${ENDCOLOR}"
    else
        echo "# ============================================================================="
        echo "# Copy ssh-key from $(hostname) to $USER@$(hostname) - yes, this is correct!" 
        ssh-copy-id $USER@$(hostname)
        echo "# ============================================================================="
    fi
else
    echo -e "${GREEN}Found ssh key for $USER@$(hostname)${ENDCOLOR}"
fi
echo 

# =============================================================================
# Add ssh config entry for LOCAL machine
echo
echo -e "# Add following entry to your ${RED}local${ENDCOLOR} ~/.ssh/config file ========================"
echo
echo -e "Host ${YELLOW}<HOSTNAME-TUNNEL>${ENDCOLOR}"
echo -e "\tProxyCommand ssh ${YELLOW}<HOSTNAME>${ENDCOLOR} \"bash $DIR_NAME/$VSCODE_NAME\"" 
echo -e "\tStrictHostKeyChecking no" 
echo -e "\tConnectTimeout $VSC_TIMEOUT"
echo -e "\tUser $USER"  
echo 
echo -e "Host ${YELLOW}<HOSTNAME-TUNNEL>${ENDCOLOR}-gpu"
echo -e "\tProxyCommand ssh ${YELLOW}<HOSTNAME>${ENDCOLOR} \"bash $DIR_NAME/$VSCODE_NAME -t -g\"" 
echo -e "\tStrictHostKeyChecking no" 
echo -e "\tConnectTimeout $VSC_TIMEOUT"
echo -e "\tUser $USER"  
echo
echo -e "# Replace ${YELLOW}<HOSTNAME-TUNNEL>${ENDCOLOR} with your preferred name. E.g. \"aim-tunnel\"."
echo -e "# Replace ${YELLOW}<HOSTNAME>${ENDCOLOR} with the hostname of the cluster. E.g. \"aim\"."
echo -e "The second entry is only needed if you sometimes wish to run vscode with gpu support."
echo "# ============================================================================="
echo 

# =============================================================================
# Add commands to .bashrc
echo 
yn=$(yes_no "Do you want to add the commands to your .bashrc file?")
if [ "$yn" == "yes" ]; then
    BASHRC_HEADLINE="# shs commands"
    SQ_ALIAS="alias sq='squeue -o \"%i %.9P %.10u %.\$(squeue -o %j | wc -L)j %.3t %.5D %.\$(squeue -o %R | wc -L )R %.\$(squeue -o %M | wc -L)M %.\$(squeue -o %b | wc -L)b %.\$(squeue -o %q | wc -L)q %.7k\" -S \"t,i\"'  #shs-sq"
    SC_ALIAS="alias sc='$DIR_NAME/$SCANCEL_NAME'  #shs-sc"
    SJUPYTER_ALIAS="alias sjupyter=\"$DIR_NAME/$JUPYTER_NAME\"  #shs-sjupyter"
    SVSCODE_ALIAS="alias svscode=\"$DIR_NAME/$VSCODE_NAME\" #shs-svscode"

    BASHRC_TAGS=("$BASHRC_HEADLINE" "shs-sq" "shs-sc" "shs-sjupyter" "shs-svscode")
    BASHRC_LINES=( "$BASHRC_HEADLINE" "$SQ_ALIAS" "$SC_ALIAS" "$SJUPYTER_ALIAS" "$SVSCODE_ALIAS" )

    # Remove all similar lines from .bashrc using tag 
    for tag in "${BASHRC_TAGS[@]}"; do
        line=$(grep "$tag" $BASHRC)
        if [ -n "$line" ]; then
            sed -i "/$tag/d" $BASHRC
        fi
    done

    # Add all lines to the end of .bashrc
    for line in "${BASHRC_LINES[@]}"; do
        echo $line >> $BASHRC
    done
    echo
    echo -e "${GREEN}Added commands to $BASHRC ${ENDCOLOR}"
    echo -e "Following  commands are available: ${BOLD}sq${NORMAL}, ${BOLD}sc${NORMAL}, ${BOLD}sjupyter${NORMAL}"
    echo -e "To use the commands, please restart your terminal or run '${HIGHLIGHT}source $BASHRC${ENDCOLOR}'"
fi
echo

# =============================================================================
# Final message
echo
echo -e "${GREEN}Installation complete :)${ENDCOLOR}"
echo 
echo -e "${YELLOW}Reminder${ENDCOLOR}: to use vscode tunnel, you need to add the previously stated entry to your local ~/.ssh/config file!"
