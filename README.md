# SHS (SLURM Helper Scripts)

Some tools to make working on the cluster with slurm a bit easier.
The number of scripts might increase :) 

> **Disclaimer:**  
> I cannot guarantee that those scripts work for you, as I only have limited testing capabilities.  

## Table of Contents: 
1. [Commands](#commands)
2. [Installation](#installation)
3. [How to use it](#htui)
    1. [VS Code Server](#htui-vscode)
    2. [Jupyter](#htui-jupyter)
4. [How it works](#hiw)
    1. [VS Code Server](#hiw-vscode)
    2. [Jupyter](#hiw-jupyter)
## <a id='commands'></a>Commands:
|command|usage|
|---|---|
|`sq`|A more expressive version of `squeue`, showing full name, resources and comments (useful for vscode-tunnel)|
|`sc`|A small helper command around `scancel`. Shows you all your jobs and then waits for you to select one using its respective index in the listing, instead of the entire job id|
|`sjupyter`|Almost like normal jupyter but in SLURM job. Has extensive CLI. most importently: `-g` for GPU support|
|`svscode`|Start a vscode server to connect to. `-g` for GPU support, `-D` to detach from terminal. Usually called implicitly by ssh call| 

## <a id='installation'></a>Installation: 
1. If you don’t already have one, generate an SSH key on the entry node. This is required to run an SSH daemon within the SLURM job.
2. Clone this repository to your user profile on the entry node, then run [`install.sh`](install.sh) and follow the on-screen instructions.

## <a id='htui'></a>How to use it
### <a id='htui-vscode'></a>VS Code Server
The installer provided an entry for the local ssh config, like this: 
```bash
Host <HOSTNAME-TUNNEL>
	ProxyCommand ssh <HOSTNAME> "bash /path/to/shs/svscode.sh"
	StrictHostKeyChecking no
	ConnectTimeout 30
	User <USERNAME>
```
When using VSCode with ssh, instead of connecting to `<HOSTNAME>`, connect to `<HOSTNAME-TUNNEL>`. 
This will automatically start a slurm job running an ssh server. If such a server is already running, it will automatically connect to the running instance. 

### <a id='htui-jupyter'></a>Jupyter
1. Start script with `sjupyter`
2. After the script started, it will display both the URL and a argument of 
shape `-L <PORT>:localhost:<PORT>`.
Copy this argument and use it in a new terminal to establish another ssh connection to the server with portforwarding. 

The Jupyter server can now be accessed from your local machine using the URL displayed by the script.

> Manually adding the portforwarding argument can be ommited if you hardcode the portforwarding in your local `~/.ssh/config` file and in this script (Within Default Setting).
E.g. adding something like: `LocalForward <PORT> localhost:<PORT>`

#### <a id='htui-jupyter-vscode'></a>Jupyter Notebooks in VS Code:

1. Open the `.ipynb` file in VS Code you want to work on.
2. Click on 'Select Kernel' in the top right corner
5. Select 'Select Another Kernel...'.
4. Select 'Existing Server' and paste the URL from above.
5. Choose Server display name, the default 'localhost' is fine. 
6. Select python kernel version.


## <a id='hiw'></a>How it works
### <a id='hiw-vscode'></a>VS Code Server
Whenever `ssh <HOSTNAME-JOB>` is called, the ProxyCommand executes the script. 
The script performs following steps: 

1. If no port was specified, it chooses a random unused port `<PORT>`
2. Start ssh server job  
    - If there is a job named `<JOBNAME>` belonging to the user running, do nothing and proceed with 3. 
    - If no such job is running:  
        1. start SLURM job running sshd as such:   
        `/usr/sbin/sshd -D -p <PORT> -f /dev/null -h <KEY_PATH>`  
        2. Waits at most `<TIMEOUT>` seconds for the job with name `<JOBNAME>` to be running (Checks every second).
        3. If after `<TIMEOUT>` seconds the job is still not running, exit script with error code `1`. 
3. If a job with name `<JOBNAME>` is running, it forwards the connection with netcat (nc) on the designated port `<PORT>`.  
`nc $(squeue --me --name=<JOBNAME> -h -O nodelist --states=R -h) <PORT>`.  
`squeue --me --name=<JOBNAME> -h -O nodelist --states=R -h` returns the worker node that is running the job. 

### <a id='hiw-jupyter'></a>Jupyter
The main issue is the port forwarding. 
This can be solved by creating a ssh connection reverse portforwarding from the worker node to the login node. 
For this to work server needs to exchange keys with itself (see the `ssh-copy-id` command).  
Afterwards the same port needs to be forwarded to the client machine.
Therefore, the user needs to create a second local terminal and connect to the server with added port forwarding argument as displayed by the script.  
If Jupyter is used in VSCode another portforwarding is needed from the node running VSCode to the node running Jupyter.
