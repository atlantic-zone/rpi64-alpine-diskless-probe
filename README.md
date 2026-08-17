# RPi Alpine Diskless Temperature Probe (`az-rpi-alpine-diskless-probe`)

Image système Alpine Linux Diskless (100 % en RAM) pour Raspberry Pi 4 et Raspberry Pi 5 avec sonde de température DS18B20 (1-Wire) et poussée des métriques vers VictoriaMetrics.

## Fonctionnalités

- **100 % Run-from-RAM (Diskless) :** Aucune écriture sur la carte SD pendant l'utilisation (protection contre la corruption et l'usure).
- **Compatibilité Universelle RPi 4 & 5 :** Le même tarball / image fonctionne sur Raspberry Pi 4 et Raspberry Pi 5 (Architecture 64-bit `aarch64`).
- **Configuration Simple FAT32 (`probe.conf`) :** Tout se régle en éditant un simple fichier texte `probe.conf` à la racine de la carte SD depuis n'importe quel PC.
- **Push Direct VictoriaMetrics :** Pousse la température via HTTP POST (`/api/v1/import/prometheus`) sans ouvrir aucun port entrant sur le Pi.
- **Auto-Provisioning SSH :** Récupère automatiquement les clés publiques SSH autorisées depuis une URL (ex: `https://github.com/ts-sz.keys`).
- **Outillage Embarqué :** `vim`, `tmux`, `curl`, `openssh`, `wpa_supplicant`.

---

## Déploiement Rapide (Mode SD)

1. Formater n'importe quelle carte SD en **FAT32**.
2. Télécharger la dernière Release `rpi-alpine-diskless-probe-*.tar.gz` depuis les Releases GitHub.
3. Extraire le contenu de l'archive directement à la racine de la carte SD.
4. Éditer le fichier `probe.conf` sur la carte SD pour adapter le `HOSTNAME` et la `LOCATION` :

```ini
HOSTNAME=celsius-fost-hq75-01
LOCATION=port-royal-b2
GPIO_PIN=4
SSH_KEYS_URL=https://github.com/ts-sz.keys
VICTORIAMETRICS_URL=http://10.200.140.109:8428/api/v1/import/prometheus
INTERVAL_SECONDS=10
```

5. Insérer la carte SD dans le Raspberry Pi 4 ou 5 et alimenter.

---

## Câblage Matériel (Sonde DS18B20)

- **VCC (Rouge) :** 3.3V (Pin 1) ou 5V (Pin 2)
- **GND (Noir/Bleu) :** GND (Pin 6)
- **DATA (Jaune) :** GPIO 4 (Pin 7)
- **Résistance de tirage (Pull-up) :** 4.7kΩ entre VCC et DATA.

---

## Métrique Produite

```text
temperature_celsius{hostname="celsius-fost-hq75-01",location="port-royal-b2",sensor="ds18b20"} 21.437
```
