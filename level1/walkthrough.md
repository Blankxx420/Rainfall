# level1

## Phase d'observation

On a un message similaire au niveau précédent

```diff
RELRO  STACK CANARY           NX            PIE             RPATH      RUNPATH      FILE
- No RELRO  No canary found   NX disabled   No PIE          No RPATH   No RUNPATH   /home/user/level1/level1
```

-   🐦 **STACK CANARY** (No canary found) : Un "canari" est une valeur de contrôle placée sur la pile pour détecter les débordements (comme les mineurs utilisaient des canaris pour détecter le gaz). Sans canari, on peut écraser la mémoire sans déclencher d'alarme du programme.

-   🧱 **NX (Disabled)** : NX signifie "Non-Executable stack". Cela veut dire que la zone mémoire de la pile n'est pas verrouillée.  on peut injecter notre propre code (un shellcode), le processeur acceptera de le lire comme des instructions.

-   🎯 **PIE (No PIE)** : Le code du programme lui-même n'est pas "Position Independent". Ses fonctions (comme le main) seront toujours chargées à des adresses mémoires fixes.

On vérifie les droits du binaire
```console
~$ ls -l
total 8
-rwsr-s---+ 1 level2 users 5138 Mar  6  2016 level1
```

Même constat que pour le level0 il possède le bit SUID

### Premiers test du binaire
```console
~$ level1@RainFall:~$ ./level1 
adawd
~$ level1@RainFall:~$ ./level1 dawd
dw
```
 
#### Premières hypothèses
- Le programme attend une entrée spécifique
- Un rapport avec une ouverture de fichier
- construction et utilisation d'un shellcode


On va vérifier nos hyposthèses

```console
~$ gdb ./level1
(gdb) disas main

```

On peut voir que le programme utilise la fonction gets() qui est notre faille.

#### Pourquoi ?
Parce qu'elle est aveugle. Quand on utilise gets(buffer), elle lit tout ce que l'utilisateur tape au clavier jusqu'à ce qu'il appuie sur la touche "Entrée" (\n), sans jamais vérifier si la taille du texte rentre dans la variable de destination.

La fonction gets() a d'ailleurs été officiellement bannie et supprimée des standards récents du C.

## Phase d'éxploitation
### Comment exploiter la faille
#### Première étape 

Pour exploiter cette faille, nous devons d'abord prouver qu'elle est bien là et mesurer précisément la taille du buffer.

On commence par préparer une longue chaine de charactère 
``` console
~$ python3 -c print('A' * 100)
```
On lance notre programme ave GDB le but est de faire segfault le programme et d'inspecter le registre **eip**.

#### Pourquoi le registre eip ?

car c'est ici que le processeur va aller chercher la prochaine instruction à executer

```console
~$ gdb ./level1
~$ (gdb) run
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA

Program received signal SIGSEGV, Segmentation fault.
0x41414141 in ?? ()
(gdb) info register eip
eip            0x41414141	0x41414141
```
 Ici on peut observer que le programme a bien segfault avec une chaîne trop longue et que le registre contient 'AAAA' en hexadecimal ce qui prouve que nous avons reussi a pousser nos lettre dans ce registre on va devoir maintenant viser précisement pour ce faire il nous faut trouver la taille exacte de notre buffer

#### Deuxième étape : Calculer la taille du buffer

Le but ici est de créer un chaine de caractère qui nous permette de déterminer la taille de notre buffer pour ce faire nous allons utiliser l'alphabet 

```console
~$ python3 -c 'print("".join([chr(i)*4 for i in range(65, 91)]))'
AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIIIJJJJKKKKLLLLMMMMNNNNOOOOPPPPQQQQRRRRSSSSTTTTUUUUVVVVWWWWXXXXYYYYZZZZ
```

Chaque lettre est représentées 4 fois car nouss avons vue que notre registre contenais 4 octets

