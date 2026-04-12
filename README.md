# Rainfall

## Description 

Projet dans le cadre de mon cursus à l'école 42 ayant pour but de réaliser un CTF sur un ISO vunérable contenant 12 niveau avec une difficultée croissante sur le thème des binaires

## Instalation

- Télécharger l'ISO
- Créer une machine virtuelle avec l'iso
    - deux coeurs minimun
    - configuration réseau en bridge
    - mettre l'iso en mode x64
- Lançer la machine virtuelle et attendre l'affichage de l'addresse IP
- connecter vous en ssh sur le user level0 sur le port 4242 avec le mot de passe level0
  ```console
  $ ssh level0@{ip_machine_virtuelle} -p 4242
  ```
- vous pouvez récuperer des fichiers si besoin grâce a la commande scp
  example ci-dessous
  ```console
    $ scp -P 4242 level0@{ip_machine_virtuelle} source destination
  ```
## Liste des failles vu au cours des differents niveau

- # Level 0 : Authentification par "Magic Number"
    La faille repose sur une logique d'authentification codée en dur (hardcoded). Le programme n'exploite pas un débordement de mémoire, mais une simple condition logique exposée :

    - Mécanisme : Le programme prend un argument, le convertit en entier (atoi), et le compare à la constante 423 (0x1a7 en hexadécimal).

    - Exploitation : En passant 423 en paramètre, la condition devient vraie.

    - Privilège : Le binaire étant SUID, le succès de cette comparaison déclenche un appel à setresuid pour usurper l'identité de l'utilisateur level1 et lance un shell via execv.

    En résumé : C'est une porte dérobée (backdoor) où la connaissance d'un nombre "magique" permet une élévation de privilèges immédiate.