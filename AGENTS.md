# AGENTS.md - Guide d'Exploitation pour Agents IA

Fichier de cadrage pour tout agent IA (Hermes / XO / Subagents) intervenant sur ce dépôt ou en SSH sur une sonde Raspberry Pi Alpine Diskless.

---

## 🎯 Identité & Rôle du Prototype

Ce projet (`atlantic-zone/rpi-alpine-diskless-probe`) fournit une distribution Alpine Linux **100 % en RAM (Diskless)** pour Raspberry Pi 4 & 5 (Architecture `aarch64` / `rpi64`).

L'objectif est d'assurer une mesure continue de température via une sonde 1-Wire DS18B20 et de pousser les métriques en HTTP POST vers VictoriaMetrics.

---

## ⚠️ RÈGLES CRITIQUES D'EXPLOITATION DISKLESS (RAM)

1. **Le système de fichiers `/` est sur `tmpfs` (RAM) :**
   Toute modification faite dans `/etc` ou dans l'arborescence racine **sera intégralement perdue au redémarrage** sauf si vous exécutez la commande de persistance :
   ```bash
   lbu commit
   ```
2. **Le fichier de configuration source est `/media/mmcblk0p1/probe.conf` :**
   Il réside sur la partition FAT32 de la carte SD. Si vous modifiez un paramètre (`HOSTNAME`, `LOCATION`, `VICTORIAMETRICS_URL`, `WIFI_SSID`), modifiez-le dans `/media/mmcblk0p1/probe.conf` et relancez le service d'initialisation :
   ```bash
   rc-service probe-init restart
   rc-service ds18b20-pusher restart
   ```
3. **Jamais de `dockerd` ou de gros daemons sur le RPi :**
   Le Pi dispose de ressources RAM/CPU dédiées à la mesure. Tout l'outillage tourne en natif OpenRC.

---

## 🛠️ Diagnostiquer une Sonde via SSH

En vous connectant en SSH sur le Raspberry Pi (`root@<IP>` ou via tunnel jump) :

### 1. Vérifier la lecture brute du capteur 1-Wire DS18B20
```bash
cat /sys/bus/w1/devices/28-*/w1_slave
```
- **Résultat attendu :**
  ```text
  72 01 4b 46 7f ff 0e 10 57 : crc=57 YES
  72 01 4b 46 7f ff 0e 10 57 t=21437
  ```
  *(La présence de `YES` confirme le bon CRC ; `t=21437` correspond à 21.437 °C).*

### 2. Statut et logs du daemon de poussée VictoriaMetrics
```bash
rc-service ds18b20-pusher status
```

### 3. Tester manuellement la poussée HTTP vers VictoriaMetrics
```bash
curl -sS -X POST "http://10.200.140.109:8428/api/v1/import/prometheus" \
  --data-binary 'temperature_celsius{hostname="test-probe",location="lab"} 20.5'
```

---

## 📌 Architecture des Fichiers Clés

| Fichier / Dossier | Rôle |
|---|---|
| `/media/mmcblk0p1/probe.conf` | Configuration source modifiable sur la carte SD FAT32 |
| `/etc/init.d/probe-init` | Service OpenRC appliquant `probe.conf` au boot (Hostname, SSH, Wi-Fi) |
| `/etc/init.d/ds18b20-pusher` | Service OpenRC gérant la boucle de lecture et poussée HTTP |
| `/usr/local/bin/ds18b20-pusher.sh` | Script Shell exécutant la boucle de mesure |
| `/etc/apk/world` | Liste des paquets Alpine installés en RAM (`vim`, `tmux`, `curl`, etc.) |
