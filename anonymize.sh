#!/usr/bin/env bash

awk '
BEGIN{
    user_id=0
    group_id=0
}

function map_user(u){
    if(!(u in users)){
        user_id++
        users[u]=sprintf("user%03d",user_id)
    }
    return users[u]
}

function map_group(g){
    if(!(g in groups)){
        group_id++
        groups[g]=sprintf("group%02d",group_id)
    }
    return groups[g]
}

# anonymize cluster name
/^valar/ {
    $1="cluster01"
}

# detect group summary lines
# pattern: group_name followed by spaces then numbers
/^[a-zA-Z0-9_-]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+/ {

    group=$1
    anon_group=map_group(group)

    printf "%-12s %-12s %12s %14s %13s %14s %14s %13s\n",
        anon_group,"",$2,$3,$4,$5,$6,$7
    next
}

# detect user lines (leading whitespace)
/^[[:space:]]+[a-zA-Z0-9_-]+/ {

    user=$1
    gsub(/^[[:space:]]+/,"",user)

    anon_user=map_user(user)

    printf "%-12s %-12s %12s %14s %13s %14s %14s %13s\n",
        "",anon_user,$2,$3,$4,$5,$6,$7
    next
}

# print all other lines unchanged
{
    print
}
'
