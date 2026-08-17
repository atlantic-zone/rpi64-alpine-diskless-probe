# 🌡️ RPi Alpine Diskless Temperature Probe (`rpi-alpine-diskless-probe`)

[![Build & Release](https://github.com/atlantic-zone/rpi-alpine-diskless-probe/actions/workflows/build-release.yml/badge.svg)](https://github.com/atlantic-zone/rpi-alpine-diskless-probe/actions/workflows/build-release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: RPi 4 & 5](https://img.shields.io/badge/Platform-Raspberry%20Pi%204%20%7C%205-red.svg)](https://www.raspberrypi.com/)
[![OS: Alpine Linux 64-bit](https://img.shields.io/badge/OS-Alpine%20Linux%2064--bit-blue.svg)](https://alpinelinux.org/)

Image système autonome **Alpine Linux Diskless (100 % en RAM)** pour Raspberry Pi 4 et 5 avec sonde de température 1-Wire DS18B20 et poussée directe des métriques vers **VictoriaMetrics**.

---

## 🚀 Fonctionnalités Clés

- **100 % Run-from-RAM (Diskless) :** Le système tourne intégralement sur `tmpfs` en mémoire RAM. La carte SD n'est soumise à aucune écriture pendant le fonctionnement (élimination totale des risques de corruption SD par coupure électrique).
- **Compatibilité Universelle RPi 4 & RPi 5 :** Image 64-bit `aarch64` unique bootant nativement sur Raspberry Pi 4 et Raspberry Pi 5.
- **Configuration Simple FAT32 (`probe.conf`) :** Tout le paramétrage (Hostname, Wi-Fi, URL VictoriaMetrics, GPIO) s'effectue en éditant un fichier texte simple à la racine de la carte SD depuis n'importe quel ordinateur.
- **Mode Push HTTP VictoriaMetrics :** Pousse directement les métriques de température (`/api/v1/import/prometheus`) sans nécessiter d'ouvrir de port entrant sur le Raspberry Pi.
- **Provisioning Clés SSH Automatique :** Récupération dynamique des clés SSH autorisées via URL (ex: `https://github.com/ts-sz.keys`).
- **Support Wi-Fi & Ethernet :** Bascule automatique sur Wi-Fi (via `WIFI_SSID` / `WIFI_PASSWORD`) ou Ethernet RJ45.
- **Outillage Système Embarqué :** `vim`, `tmux`, `curl`, `openssh`, `wpa_supplicant`.

---

## 🛠️ Guide d'Écriture de la Carte SD (Linux / macOS / Windows)

Le déploiement se fait sur une simple partition **FAT32**.

### 1. Préparation de la carte SD (Formatage FAT32)

- **Windows :** Clic droit sur la carte SD dans l'Explorateur d'icônes ➔ **Formater** ➔ Système de fichiers : **FAT32** (ou utiliser *Raspberry Pi Imager* avec l'option Erase/FAT32).
- **macOS :** Ouvrir le **Utilitaire de disque** ➔ Sélectionner la carte SD ➔ **Effacer** ➔ Format : **MS-DOS (FAT)**.
- **Linux :**
  ```bash
  sudo mkfs.vfat -F 32 -n "RPI-PROBE" /dev/sdX1
  ```

---

### 2. Copie des fichiers système

1. Télécharger la dernière Release `rpi-alpine-diskless-probe-v*.tar.gz` depuis les [Releases GitHub](https://github.com/atlantic-zone/rpi-alpine-diskless-probe/releases).
2. Extraire l'intégralité du contenu de l'archive à la racine de la carte SD.

#### Commandes d'extraction par OS :

- **Linux / macOS (Terminal) :**
  ```bash
  tar -xzf rpi-alpine-diskless-probe-v1.0.0.tar.gz -C /Volumes/RPI-PROBE/   # macOS
  sudo tar -xzf rpi-alpine-diskless-probe-v1.0.0.tar.gz -C /media/user/RPI-PROBE/ # Linux
  ```
- **Windows :** Utiliser 7-Zip ou WinRAR pour extraire tous les fichiers directement sur la carte `E:\` (ou lettre attribuée).

---

### 3. Personnalisation de la sonde (`probe.conf`)

À la racine de la carte SD, renommer `probe.conf.example` en `probe.conf` (ou créer `probe.conf`) et l'éditer avec un éditeur de texte (Bloc-notes, VS Code, Nano) :

```ini
# Configuration Sonde Température RPi Alpine Diskless
HOSTNAME=celsius-fost-hq75-01
LOCATION=port-royal-b2
GPIO_PIN=4
SSH_KEYS_URL=https://github.com/ts-sz.keys
VICTORIAMETRICS_URL=http://10.200.140.109:8428/api/v1/import/prometheus
INTERVAL_SECONDS=10

# Optionnel : Configuration Wi-Fi (laisser vide si connecté en câble Ethernet RJ45)
WIFI_SSID=MonReseauWifi
WIFI_PASSWORD=MonMotDePasseSecret
```

---

## 🔌 Câblage Matériel (Sonde DS18B20 1-Wire)

Connecter la sonde DS18B20 au port GPIO du Raspberry Pi (Pinout standard GPIO 4) :

```
Sonde DS18B20              Raspberry Pi GPIO
┌─────────────┐            ┌────────────────────────────────┐
│ VCC (Rouge) ├────────────┤ Pin 1  (3.3V)                  │
│             │   [R=4.7kΩ]│                                │
│ DATA (Jaune)├───┬────────┤ Pin 7  (GPIO 4 / Data 1-Wire)  │
│             │   │        │                                │
│ GND (Noir)  ├───┴────────┤ Pin 6  (GND)                   │
└─────────────┘            └────────────────────────────────┘
```
*Note : Une résistance de tirage (Pull-up) de **4.7 kΩ** est requise entre les lignes VCC (3.3V) et DATA.*

---

## 📊 Métrique Produite (VictoriaMetrics / Prometheus)

La métrique envoyée à chaque intervalle de temps configuré :

```text
# HELP temperature_celsius Ambient temperature in Celsius from DS18B20 sensor
# TYPE temperature_celsius gauge
temperature_celsius{hostname="celsius-fost-hq75-01",location="port-royal-b2",sensor="ds18b20"} 21.437
```

---

## 🔍 Vérification & Diagnostic

Une fois le Raspberry Pi démarré :

1. **Vérifier le statut du service de poussée :**
   ```bash
   rc-service ds18b20-pusher status
   ```
2. **Tester la lecture de la sonde en local :**
   ```bash
   cat /sys/bus/w1/devices/28-*/w1_slave
   ```
3. **Vérifier que le système est bien 100 % en RAM :**
   ```bash
   df -h /
   # Doit afficher : tmpfs sur /
   ```

---

## 📜 Licence

Projet sous licence [MIT](LICENSE) - © Atlantic Zone / Strategic Zone.
