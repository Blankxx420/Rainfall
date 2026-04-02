FROM kalilinux/kali-rolling

ENV DEBIAN_FRONTEND=noninteractive

# 1. Ajout de l'architecture i386 (crucial pour Rainfall)
RUN dpkg --add-architecture i386 && apt-get update

# 2. Installation des outils de compilation et de debug
RUN apt-get install -y --no-install-recommends \
    build-essential \
    gcc-multilib \
    gdb \
    ltrace \
    strace \
    python3 \
    python3-pip \
    python3-dev \
    git \
    curl \
    wget \
    vim \
    binutils \
    hexedit \
    nasm \
    libc6:i386 \
    libncurses5:i386 \
    libstdc++6:i386 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 3. Installation de GEF (GDB Enhanced Features) 
# Très utile pour voir la stack et les registres en un coup d'œil
RUN wget -O ~/.gdbinit-gef.py -q https://gef.blah.cat/py \
    && echo "source ~/.gdbinit-gef.py" >> ~/.gdbinit

# 4. Pwntools pour scripter les exploits
RUN pip3 install --break-system-packages pwntools

WORKDIR /root/rainfall