#!/usr/bin/env python3

import subprocess
import re


def run(cmd):
    return subprocess.check_output(cmd, shell=True).decode().strip()


def parse_gpu(text):
    if not text:
        return 0
    m = re.search(r'gpu(?::[^:]+)?:([0-9]+)', text)
    if m:
        return int(m.group(1))
    return 0


# ---------------- CLUSTER SUMMARY ----------------

def print_cluster_summary():

    cluster = run("scontrol show config | awk -F= '/ClusterName/ {print $2}'")

    nodes_total = int(run("sinfo -h -o '%D' | awk '{s+=$1} END{print s}'"))
    nodes_down = int(run("sinfo -h -t down,drain,drng -o '%D' | awk '{s+=$1} END{print s+0}'"))
    nodes_active = nodes_total - nodes_down

    cpu_total = int(run("sinfo -h -o '%C' | awk -F/ '{s+=$4} END{print s}'"))
    cpu_used = int(run("squeue -h -o '%C' | awk '{s+=$1} END{print s+0}'"))
    cpu_free = cpu_total - cpu_used

    gpu_total = int(run("""
sinfo -h -o '%G %D' | awk '
{
    g=0
    split($1,a,",")
    for(i in a){
        split(a[i],b,":")
        g+=b[length(b)]
    }
    s+=g*$2
}
END{print s+0}'
"""))

    gpu_used = 0
    out = subprocess.check_output("squeue -h -o '%b'", shell=True).decode().splitlines()

    for line in out:
        gpu_used += parse_gpu(line)

    gpu_free = gpu_total - gpu_used

    print("")
    print("CLUSTER SUMMARY")
    print("-"*124)

    header = "{:<14} {:>14} {:>14} {:>24} {:>24}"
    row    = "{:<14} {:>14} {:>14} {:>24} {:>24}"

    print(header.format(
        "CLUSTER",
        "ACTIVE_NODES",
        "DOWN_NODES",
        "CPU(TOTAL/USED/FREE)",
        "GPU(TOTAL/USED/FREE)"
    ))

    print("-"*124)

    cpu_field = f"{cpu_total}/{cpu_used}/{cpu_free}"
    gpu_field = f"{gpu_total}/{gpu_used}/{gpu_free}"

    print(row.format(
        cluster,
        nodes_active,
        nodes_down,
        cpu_field,
        gpu_field
    ))

    print("-"*124)
    print("")

# ---------------- JOB SUMMARY ----------------

def add_group(lst,g,aj,ac,ag,pj,pc,pg):
    if not lst:
        lst.append([g,aj,ac,ag,pj,pc,pg])
    elif lst[-1][0]!=g:
        lst.append([g,aj,ac,ag,pj,pc,pg])
    else:
        lst[-1][1]+=aj
        lst[-1][2]+=ac
        lst[-1][3]+=ag
        lst[-1][4]+=pj
        lst[-1][5]+=pc
        lst[-1][6]+=pg


def add_user(lst,g,u,aj,ac,ag,pj,pc,pg):
    if not lst:
        lst.append([g,u,aj,ac,ag,pj,pc,pg])
    elif lst[-1][1]!=u or lst[-1][0]!=g:
        lst.append([g,u,aj,ac,ag,pj,pc,pg])
    else:
        lst[-1][2]+=aj
        lst[-1][3]+=ac
        lst[-1][4]+=ag
        lst[-1][5]+=pj
        lst[-1][6]+=pc
        lst[-1][7]+=pg


def print_job_summary(groups,users):

    user_cnt=0

    header="{:<20} {:<18} {:>12} {:>14} {:>12} {:>14} {:>14} {:>12}"

    print(header.format(
        "GROUP","USER",
        "ACTIVE_JOBS","ACTIVE_CORES","ACTIVE_GPUS",
        "PENDING_JOBS","PENDING_CORES","PENDING_GPUS"
    ))

    print("-"*124)

    ta_j=ta_c=ta_g=tp_j=tp_c=tp_g=0

    for g in groups:

        ta_j+=g[1]
        ta_c+=g[2]
        ta_g+=g[3]
        tp_j+=g[4]
        tp_c+=g[5]
        tp_g+=g[6]

        print(header.format(g[0].decode(),"",g[1],g[2],g[3],g[4],g[5],g[6]))

        while users[user_cnt][0]==g[0]:

            u=users[user_cnt]

            print(header.format("",u[1].decode(),u[2],u[3],u[4],u[5],u[6],u[7]))

            user_cnt+=1
            if user_cnt>len(users)-1:
                break

        print("-"*124)

    print(header.format("TOTALS","",ta_j,ta_c,ta_g,tp_j,tp_c,tp_g))


# ---------------- MAIN ----------------

def main():

    print_cluster_summary()

    cmd=subprocess.Popen(
        "squeue --Format=account,username,numcpus,state,gres --array --noheader | sort -k1,1 | uniq -c",
        shell=True,
        stdout=subprocess.PIPE
    )

    users=[]
    groups=[]

    for line in cmd.stdout:

        parts=line.split()

        njobs=int(parts[0])
        group=parts[1]
        user=parts[2]
        cores=int(parts[3])
        state=parts[4]
        gres=parts[5] if len(parts)>5 else b''

        gpus=parse_gpu(gres.decode())

        if state.decode()=="PENDING":
            add_group(groups,group,0,0,0,njobs,njobs*cores,njobs*gpus)
            add_user(users,group,user,0,0,0,njobs,njobs*cores,njobs*gpus)
        else:
            add_group(groups,group,njobs,njobs*cores,njobs*gpus,0,0,0)
            add_user(users,group,user,njobs,njobs*cores,njobs*gpus,0,0,0)

    print_job_summary(groups,users)


if __name__=="__main__":
    main()

