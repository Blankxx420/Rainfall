#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>

int main(int argc, char **argv) {
    int resultat;

    resultat = atoi(argv[1]);
    if (resultat == 423) 
    {
        char *cmd = strdup("/bin/sh");
        char *args[2];
        args[0] = cmd;
        args[1] = NULL

        gid_t egid = getegid();
        uid_t euid = geteuid();
        setresgid(egid, egid, egid);
        setresuid(euid, euid, euid);

        execv("/bin/sh", args);
    } 
    else 
    {
       fwrite("No !\n", 1, 5, stderr);
    }
    return 0; 
}