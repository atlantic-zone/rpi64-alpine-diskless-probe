# RPi64 Alpine Diskless Probe

Image 100% RAM. Tout ce qui est installe ici disparait au reboot.
RAM totale sur Pi 3 : ~450 Mo de tmpfs. Verifier avant d'installer : `df -h /`

---

## bore (tunnel TCP inverse)

Pas package dans Alpine. Binaire statique musl.

```sh
curl -sSL https://github.com/ekzhang/bore/releases/download/v0.6.0/bore-v0.6.0-aarch64-unknown-linux-musl.tar.gz \
  | tar -xz -C /usr/local/bin/ && chmod +x /usr/local/bin/bore && bore --version
```

Ouvrir un tunnel vers le relais (SSH local port 22) :

```sh
bore local 22 --to edge.sh.zone --secret "$BORE_SECRET" --port 0
```

Le relais repond `listening at edge.sh.zone:PORT`. C'est ce port qu'on utilise pour se connecter.
`--port 0` = port attribue au hasard. Mettre un numero fixe pour un port reserve.

En arriere-plan, avec relance auto :

```sh
setsid sh -c 'while :; do bore local 22 --to edge.sh.zone --secret "$BORE_SECRET" --port 0; sleep 5; done' \
  > /var/log/bore.log 2>&1 &
tail -f /var/log/bore.log
```

Poids : ~1 Mo.

---

## sshx (terminal web partage)

Pas package dans Alpine. Binaire statique musl.

```sh
curl -sSL https://s3.amazonaws.com/sshx/sshx-aarch64-unknown-linux-musl.tar.gz \
  | tar -xz -C /usr/local/bin/ && chmod +x /usr/local/bin/sshx && sshx --version
```

Lancer une session (renvoie une URL a partager) :

```sh
sshx
```

En arriere-plan :

```sh
setsid sshx > /var/log/sshx.log 2>&1 &
sleep 3 && cat /var/log/sshx.log
```

Poids : ~2,7 Mo.
Attention : l'URL donne un shell root complet a qui l'ouvre. Session ephemere, ne pas laisser tourner.

---

## Outils Raspberry Pi (vcgencmd, otp, temperature)

Le meta-paquet `raspberrypi-utils` tire python3 + perl + bash + sudo = **89 Mo de RAM**.
Ne jamais l'installer sur cette image. Installer uniquement le sous-paquet voulu :

```sh
apk add raspberrypi-utils-vcgencmd     # 80 Ko  - temperature, OTP, throttling
apk add raspberrypi-utils-vcmailbox    # 80 Ko  - mailbox firmware brut
apk add raspberrypi-utils-pinctrl      # 144 Ko - etat des GPIO
```

Usage courant :

```sh
vcgencmd measure_temp
vcgencmd get_throttled
vcgencmd otp_dump | grep '^17:'   # 1020000a = netboot OFF / 3020000a = netboot ON
```

A eviter : `raspberrypi-utils-raspinfo` (tire bash+sudo), `-otpset` (tire python3, et il est casse
sur Pi 3), `-ovmerge` et `-overlaycheck` (tirent perl).

---

## Editeur

`vi` de busybox est deja present et gratuit.
`vim` complet coute 33 Mo de RAM (tire vim-common + xxd) :

```sh
apk add vim
```

---

## Console locale HDMI + clavier

Deja embarque dans l'image : `kbd-bkeymaps`.
La disposition se regle dans `probe.conf` (`KEYMAP=us-intl`, `fr-fr`, `fr-bepo`...).

Changer a chaud sans rebooter :

```sh
loadkmap < /usr/share/bkeymaps/fr/fr.bkm
ls /usr/share/bkeymaps/          # dispositions disponibles
```

---

## Wi-Fi

Deja embarque : `wpa_supplicant`, `wireless-regdb`, `linux-firmware-brcm`.
Se configure dans `probe.conf` (`WIFI_SSID`, `WIFI_PASSWORD`, `WIFI_COUNTRY`) puis reboot.

Connexion manuelle immediate :

```sh
wpa_passphrase "MonSSID" "MonMotDePasse" > /etc/wpa_supplicant/wpa_supplicant.conf
rc-service wpa_supplicant restart
udhcpc -i wlan0
iw dev wlan0 link            # necessite apk add iw
```

---

## Divers

```sh
apk add rsync              # 1,5 Mo
apk add jq                 # 1 Mo
apk add prometheus-node-exporter   # 15 Mo, alternative legere a telegraf
```

---

## Verifier la RAM

```sh
df -h /            # occupation du tmpfs racine
free -m            # memoire
awk -F: '/^P:/{p=$2} /^I:/{printf "%10d  %s\n", $2, p}' /lib/apk/db/installed | sort -rn | head -20
```

La derniere commande liste les 20 paquets les plus gros, en octets.
