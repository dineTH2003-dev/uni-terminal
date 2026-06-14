# Commands

## CLI

```bash
unishell init
unishell doctor
unishell help
unishell version
```

## Workspace Aliases

```bash
ws       # cd ~/workspace
uni      # cd ~/workspace/university
proj     # cd ~/workspace/projects
devops   # cd ~/workspace/devops
learn    # cd ~/workspace/learning
scripts  # cd ~/workspace/scripts
```

## Assignment Generator

```bash
mkassign dbms-lab-01
```

Creates:

```text
~/workspace/university/dbms-lab-01/
|-- questions/
|-- answers/
|-- screenshots/
|-- references/
|-- submissions/
`-- README.md
```

## Project Generator

```bash
mkproject my-app --basic
mkproject api-demo --python
mkproject web-demo --node
```

All projects are created under `~/workspace/projects`.

## Git Helpers

```bash
gstatus
gsave "initial commit"
gpush
glog
gnew feature/login
gundo
```

`gundo` asks for confirmation before running `git reset --soft HEAD~1`.

## System Helpers

```bash
sysinfo
ports
myip
diskcheck
memcheck
service-check nginx
docker-clean
```

`myip` prints a warning if the public IP endpoint cannot be reached.
