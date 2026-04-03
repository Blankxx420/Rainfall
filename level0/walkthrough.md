# Level0

## Phase d'observation
En me connectant j'ai ce message
```diff
+ GCC stack protector support:          Enabled
- Strict user copy checks:              Disabled
+ Restrict /dev/mem access:               Enabled
+ Restrict /dev/kmem access:              Enabled
- grsecurity / PaX: No GRKERNSEC
- Kernel Heap Hardening: No KERNHEAP
- System-wide ASLR (kernel.randomize_va_space): Off (Setting: 0)

RELRO           STACK CANARY      NX            PIE             RPATH      RUNPATH      FILE

-No RELRO        No canary found   NX enabled    No PIE          No RPATH   No RUNPATH   /home/user/level0/level0
```

C'est un rapport de sécurité (généré par un outil d'analyse) qui indique exactement les défenses actives sur le système

voici les informations que l'on peut en retirer

-  📍**ASLR (Off)** : L'ASLR mélange aléatoirement les adresses mémoire à chaque exécution. Comme il est désactivé, l'adresse de la pile ou des fonctions sera toujours exactement la même.

-   🐦 **STACK CANARY** (No canary found) : Un "canari" est une valeur de contrôle placée sur la pile pour détecter les débordements (comme les mineurs utilisaient des canaris pour détecter le gaz). Sans canari, on peut écraser la mémoire sans déclencher d'alarme du programme.

-   🧱 **NX (Enabled)** : NX signifie "Non-Executable stack". Cela veut dire que la zone mémoire de la pile est verrouillée. Même si on arrive à y injecter notre propre code (un shellcode), le processeur refusera de le lire comme des instructions.

-   🎯 **PIE (No PIE)** : Le code du programme lui-même n'est pas "Position Independent". Ses fonctions (comme le main) seront toujours chargées à des adresses mémoires fixes.

Je regarde les droits sur le binaire
```console
ls -l
total 732
-rwsr-x---+ 1 level1 users 747441 Mar  6  2016 level0
```
on peut voir que le binaire prend les droits du propriétaire lors de l'execution au cause du bit SUID (Set-User-ID).

Je test ensuite l'excutable
    
``` console
$ ./level0
Segmentation fault (core dumped)
$ ./level0 test
No !
```

Plusieurs Hypothèses

- le Segfault est une faille car le programme essaye de lire au dela de la memoire donc on pourrais l'utiliser
- le programme requiert un argument ou plusieur mais celui-ci est incorrect je dois déterminer le bon


### Analyse de la première hypothèse

on va tester avec le débuggeur GDB pour voir si on peut avoir plus d'information sur le segfault afin de déterminé si il est exploitable

``` console
$ gdb ./level0
(gdb) run
Starting program: /home/user/level0/level0 
Program received signal SIGSEGV, Segmentation fault.
0x08049aff in ____strtol_l_internal ()
```

C'est la version interne de la fonction C standard strtol (qui signifie "string to long"). Son rôle est de convertir une chaîne de caractères (du texte) en un nombre entier.

Quand une fonction de bibliothèque comme celle-ci fait un Segfault, c'est presque toujours parce qu'elle a reçu un mauvais argument en entrée, comme un pointeur vers une adresse mémoire qui n'existe pas ou qui est interdite.

Pour mener l'enquête, nous devons "remonter le temps". Nous savons où le programme a planté, mais nous voulons savoir quelle fonction a appelé strtol en lui donnant ce mauvais argument.

Pour cela dans GDB j'utilise la commande **bt** (backtrace) qui a pour but d'afficher l'historique des appels de fonctions afin de voir quel fonction à appelée strtol

```console
(gdb) bt
#0  0x08049aff in ____strtol_l_internal ()
#1  0x08049aaa in strtol ()
#2  0x0804972f in atoi ()
#3  0x08048ed9 in main ()
```

Ma déduction final

le programme attend un argument comme je n'est pas mis d'argument **argv[1]** est un pointeur **NULL** (l'adresse mémoire 0x0). atoi essaie de lire du texte à cette adresse interdite et c'est le crash immédiat. Ce n'est donc pas une faille exploitable pour prendre le contrôle, c'est juste un programme qui a été codé sans vérifier les erreurs.

### Analyse de la deuxième hypotèse

Nous savons que notre programme requiert minimum un arguments et que cet argument doit probablement etre un **int** on va devoir regarder le code en Assembleur avec GDB pour avoir plus d'information

```console
(gdb) disas main
Dump of assembler code for function main:
   0x08048ec0 <+0>:	push   %ebp
   0x08048ec1 <+1>:	mov    %esp,%ebp
   0x08048ec3 <+3>:	and    $0xfffffff0,%esp
   0x08048ec6 <+6>:	sub    $0x20,%esp
   0x08048ec9 <+9>:	mov    0xc(%ebp),%eax
   0x08048ecc <+12>:	add    $0x4,%eax
   0x08048ecf <+15>:	mov    (%eax),%eax
   0x08048ed1 <+17>:	mov    %eax,(%esp)
   0x08048ed4 <+20>:	call   0x8049710 <atoi>
   0x08048ed9 <+25>:	cmp    $0x1a7,%eax
```
On peut voir une comparaison juste apres le call de atoi c'est notre valeur de int que nous cherchons **%eax** est la valeur de retour de atoi donc **$0x1a7** est notre nombre.

Le signe $ indique que c'est une valeur brute (une constante), et le 0x indique que c'est un nombre écrit en hexadécimal (base 16).

Pour retrouver la valeur on va le faire avec echo

```console
echo $((0x1a7))
423
```

On relance notre programme avec notre valeur
```console
./level0 423
$
```
ici un bash on verifie nos droit
```console
id
uid=2030(level1) gid=2020(level0) groups=2030(level1),100(users),2020(level0)

```

nous avons bien obtenu les droits du user level1 il ne reste plus que a afficher le mot de passe

```console
cat /home/user/level1/.pass
???????????????????????????????????????
```

Dernière étape reconstruire le binaire

Vous pouvez retrouver le binaire reconstruit en C dans le dossier source 