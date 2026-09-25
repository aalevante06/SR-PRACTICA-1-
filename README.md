# 🔒 FortiGate — Security Lab 2174

**Laboratorio de Seguridad de Redes — FortiGate / GNS3**

> Implementación de una topología segmentada con FortiGate, switch L2, una VLAN de usuarios y dos VLAN de servidores. El laboratorio aplica políticas de acceso, NAT, HTTPS, MariaDB, IPS para SQL Injection, cuarentena de atacantes, filtrado de ejecutables y protección DoS.

---

## 🎬 Video de demostración

> **Video:** [Ver demostración en YouTube](PENDIENTE)

> El enlace final del video debe mantenerse al inicio del repositorio, como exige la tarea.

---

## 📑 Tabla de contenido

1. [Objetivo del laboratorio](#-objetivo-del-laboratorio)
2. [Cumplimiento de requisitos](#-cumplimiento-de-requisitos)
3. [Topología y direccionamiento](#-topología-y-direccionamiento)
4. [Componentes del entorno](#-componentes-del-entorno)
5. [Funcionamiento de la configuración](#-funcionamiento-de-la-configuración)
6. [Políticas de FortiGate](#-políticas-de-fortigate)
7. [Perfiles de seguridad](#-perfiles-de-seguridad)
8. [Configuración del switch](#-configuración-del-switch)
9. [Servidores](#-servidores)
10. [Validación de la implementación](#-validación-de-la-implementación)
11. [Capturas de pantalla](#-capturas-de-pantalla)
12. [Archivos del repositorio](#-archivos-del-repositorio)
13. [Limitaciones observadas](#-limitaciones-observadas)

---

## 🎯 Objetivo del laboratorio

Implementar una infraestructura de red segmentada y protegida mediante un firewall FortiGate, utilizando VLANs para separar usuarios, servidor web y servidor de base de datos.

El firewall controla la comunicación entre segmentos, proporciona salida a Internet mediante NAT, restringe el acceso al servidor web a HTTPS, impide conexiones directas de los usuarios hacia la base de datos y permite que el servidor web se comunique con MariaDB únicamente mediante TCP/3306.

También se implementan mecanismos de seguridad adicionales: IPS con una firma personalizada para SQL Injection, cuarentena de la IP atacante, filtrado de archivos ejecutables, Application Control y una política DoS con umbrales para limitar floods y escaneos.

---

## ✅ Cumplimiento de requisitos

| Requisito | Implementación |
|---|---|
| FortiGate configurado por GUI | FortiGate-VM64-KVM administrado mediante GUI |
| Ruta por defecto | WAN `port1` obtiene gateway por DHCP desde NAT1 |
| NAT | Política `USUARIOS-TO-INTERNET` con NAT habilitado |
| Política 1: Usuarios → WEB 443 | `USUARIOS-TO-WEB-HTTPS`, servicio HTTPS |
| Política 2: bloquear Usuarios → DB 3306 | `BLOCK-USUARIOS-TO-DB-3306`, acción DENY |
| DPI | Perfil `custom-deep-inspection` configurado en la política hacia WEB |
| Detección SQL Injection | Firma IPS personalizada `SQLI-2174` |
| Bloqueo SQL Injection | Sensor `SQLI-QUARANTINE-2174` |
| Cuarentena del atacante | Acción `Quarantine`, IP observada como `Banned IP` |
| WEB → DB solo TCP/3306 | `WEB-TO-DB-MYSQL` + `BLOCK-WEB-TO-DB-OTHER` |
| Bloqueo de `.exe` | File Filter `BLOCK-EXE-2174` |
| Filtrado de aplicaciones | `APP-CONTROL-USUARIOS-2174` |
| Rate limiting / DoS | `DOS-PROTECTION-WEB-2174` |
| Switch con VLANs | VLAN 10, 20 y 30 + trunk 802.1Q |
| Seguridad básica del switch | Port Security Sticky + modo restrict |
| 2 servidores `/28` | WEB `10.21.74.130/28`, DB `10.21.74.146/28` |
| Usuarios `/25` | VLAN 10 `10.21.74.0/25` |
| DHCP | Rango configurado en VLAN 10 |
| WEB Server HTTPS | Apache2 en TCP/443 |
| DB Server | MariaDB en TCP/3306 |
| Scripts utilizados | Directorio `scripts/` |
| Running-configs | Directorio `files/` |
| Capturas y diagramas | Directorio `images/` |

---

## 🗺️ Topología y direccionamiento
La siguiente imagen muestra la topología implementada en GNS3:

<p align="center">
  <img src="images/01_topologia_gns3.png" alt="Topología del laboratorio en GNS3" width="900">
</p>

### Tabla de direccionamiento

| Dispositivo / Red | Interfaz | Dirección | Función |
|---|---|---:|---|
| FortiGate WAN | `port1` | DHCP (`192.168.42.x/24` durante el laboratorio) | Salida a NAT1/Internet |
| FortiGate trunk | `port2` | Sin IP física | Transporte VLAN 10, 20 y 30 |
| FortiGate administración | `port3` | `192.168.79.99/24` | Acceso GUI |
| VLAN 10 USUARIOS | `port2.10` | `10.21.74.1/25` | Gateway de usuarios |
| VLAN 20 WEB | `port2.20` | `10.21.74.129/28` | Gateway WEB |
| VLAN 30 DATABASE | `port2.30` | `10.21.74.145/28` | Gateway DB |
| PC-USER-2174 | `ens3` | DHCP, ej. `10.21.74.10/25` | Cliente de pruebas |
| WEB-SV-2174 | `ens3` | `10.21.74.130/28` | Apache HTTPS |
| DB-SV-2174 | `ens3` | `10.21.74.146/28` | MariaDB |

### VLANs

| VLAN | Nombre | Red | Gateway |
|---:|---|---|---|
| 10 | USUARIOS | `10.21.74.0/25` | `10.21.74.1` |
| 20 | WEB | `10.21.74.128/28` | `10.21.74.129` |
| 30 | DATABASE | `10.21.74.144/28` | `10.21.74.145` |

---

## 🧩 Componentes del entorno

| Componente | Descripción |
|---|---|
| Emulador | GNS3 |
| Firewall | FortiGate-VM64-KVM / FortiOS 7.0.9 |
| Switch | Cisco IOSvL2 / switch L2 |
| Usuario | Ubuntu Server usado como cliente |
| WEB Server | Ubuntu + Apache2 + HTTPS |
| DB Server | Ubuntu + MariaDB |
| Administración FortiGate | `http://192.168.79.99:8080` mediante VMware VMnet1 |

---

## 🔬 Funcionamiento de la configuración

### Segmentación
El enlace entre `port2` del FortiGate y `Gi0/0` del switch funciona como trunk 802.1Q y transporta VLAN 10, 20 y 30.

- `Gi0/1` → VLAN 10 — USUARIOS
- `Gi0/2` → VLAN 20 — WEB
- `Gi0/3` → VLAN 30 — DATABASE

### Internet y NAT
`USUARIOS-TO-INTERNET` permite la salida de VLAN 10 mediante NAT. Las policies `TEMP-WEB-TO-INTERNET` y `TEMP-DB-TO-INTERNET` se usaron únicamente para instalaciones y quedan deshabilitadas al final.

### Usuarios → WEB
`USUARIOS-TO-WEB-HTTPS` permite solamente HTTPS/TCP 443 desde Usuarios hacia `WEB-SERVER`.

### Usuarios → DB
`BLOCK-USUARIOS-TO-DB-3306` bloquea MYSQL/TCP 3306 desde Usuarios hacia `DB-SERVER`.

### WEB → DB
`WEB-TO-DB-MYSQL` permite TCP/3306 y `BLOCK-WEB-TO-DB-OTHER` bloquea cualquier otro tráfico entre ambos servidores.

### SQL Injection
Se creó `SQLI-2174` dentro del sensor `SQLI-QUARANTINE-2174`, con acción `Quarantine` y Packet Logging.

La validación controlada usa una policy HTTP temporal. FortiGate muestra **Attack Detected** y `10.21.74.10` aparece en **Quarantine Monitor / Banned IP** con origen `IPS`.

### Filtrado de ejecutables
El perfil `BLOCK-EXE-2174` bloquea ejecutables descargados mediante HTTP. `APP-CONTROL-USUARIOS-2174` complementa la política de acceso a Internet.

### Protección DoS
`DOS-PROTECTION-WEB-2174` utiliza estos umbrales:

| Anomalía | Acción | Threshold |
|---|---|---:|
| `tcp_syn_flood` | Block | 100 |
| `tcp_port_scan` | Block | 50 |
| `tcp_src_session` | Block | 100 |
| `tcp_dst_session` | Block | 200 |
| `icmp_flood` | Block | 50 |

---

## 🔥 Políticas de FortiGate

| Política | Origen → Destino | Servicio | Acción | NAT |
|---|---|---|---|---|
| `USUARIOS-TO-INTERNET` | VLAN10 → WAN | ALL | ACCEPT | ON |
| `USUARIOS-TO-WEB-HTTPS` | VLAN10 → WEB | HTTPS | ACCEPT | OFF |
| `BLOCK-USUARIOS-TO-DB-3306` | VLAN10 → DB | MYSQL | DENY | OFF |
| `WEB-TO-DB-MYSQL` | WEB → DB | MYSQL | ACCEPT | OFF |
| `BLOCK-WEB-TO-DB-OTHER` | WEB → DB | ALL | DENY | OFF |
| `TEMP-WEB-TO-INTERNET` | WEB → WAN | ALL | ACCEPT | ON — **DISABLED** |
| `TEMP-DB-TO-INTERNET` | DB → WAN | ALL | ACCEPT | ON — **DISABLED** |
| `TEST-SQLI-HTTP-2174` | VLAN10 → WEB | HTTP | ACCEPT | OFF — **TEMPORAL/DISABLED** |
| `TEST-BLOCK-EXE-2174` | VLAN10 → WEB | HTTP | ACCEPT | OFF — **TEMPORAL/DISABLED AL FINAL** |

---

## 🛡️ Perfiles de seguridad

### IPS
**Sensor:** `SQLI-QUARANTINE-2174`

**Custom Signature:** `SQLI-2174`

```text
F-SBID( --name "SQLI.2174"; --severity high; --protocol tcp; --flow from_client; --pattern "%20UNION%20SELECT%20"; --context PACKET_ORIGIN; --no_case; )
```

Acción: `Quarantine`  
Packet Logging: `Enabled`

### File Filter
**Perfil:** `BLOCK-EXE-2174`

- Protocolo: HTTP
- Dirección: Incoming
- File Type: EXE
- Acción: Block

### Application Control
**Perfil:** `APP-CONTROL-USUARIOS-2174`

- P2P → Block
- Proxy → Block
- otras categorías → Monitor/Pass según configuración
- QUIC → Block

### SSL Inspection
`custom-deep-inspection` quedó configurado para la policy HTTPS. En esta instancia se observó que el cliente seguía recibiendo el certificado autofirmado original del WEB Server, por lo que la prueba funcional del IPS/SQLi se realizó mediante una policy HTTP temporal controlada.

### DoS
**Policy:** `DOS-PROTECTION-WEB-2174`

---

## 🔀 Configuración del switch

```text
Gi0/0 → TRUNK hacia FortiGate
Gi0/1 → ACCESS VLAN 10
Gi0/2 → ACCESS VLAN 20
Gi0/3 → ACCESS VLAN 30
```

Trunk permitido:

```text
10,20,30
```

Seguridad básica:

- máximo 1 MAC por puerto de acceso
- Sticky MAC
- violation mode `restrict`

---

## 🖥️ Servidores

### WEB-SV-2174
```text
IP:      10.21.74.130/28
Gateway: 10.21.74.129
Servicio: Apache2 HTTPS
Puerto:  443/TCP
```

### DB-SV-2174
```text
IP:      10.21.74.146/28
Gateway: 10.21.74.145
Servicio: MariaDB
Puerto:  3306/TCP
Base:    lab2174
Usuario: labweb@10.21.74.130
```

---

## ✅ Validación de la implementación

### Prueba 01 — VLAN y DHCP
Cliente en VLAN 10 obtiene IP automáticamente dentro de `10.21.74.0/25`.

**Evidencia:** `images/12_prueba_dhcp_usuario.png`

### Prueba 02 — Internet y NAT
Desde PC-USER se comprueba salida a Internet y DNS.

**Evidencia:** `images/13_prueba_internet_nat.png`

### Prueba 03 — Usuarios → WEB HTTPS
```bash
curl -k https://10.21.74.130
```

**Evidencia:** `images/14_prueba_usuario_web_https.png`

### Prueba 04 — Usuarios → DB bloqueado
```bash
nc -vz -w 3 10.21.74.146 3306
```

**Evidencia:** `images/15_prueba_usuario_db_bloqueado.png`

### Prueba 05 — WEB → DB MYSQL
```bash
nc -vz -w 3 10.21.74.146 3306
```

**Evidencia:** `images/16_prueba_web_db_mysql.png`

### Prueba 06 — WEB → DB otros protocolos bloqueados
**Evidencia:** `images/17_prueba_web_db_otros_bloqueados.png`

### Prueba 07 — SQL Injection
```bash
curl -v "http://10.21.74.130/?id=1%20UNION%20SELECT%201,2,3"
```

FortiGate muestra **Attack Detected** y la IP aparece como Banned IP por IPS.

**Evidencias:**
- `images/18_sqli_attack_detected.png`
- `images/19_sqli_quarantine_monitor.png`

### Prueba 08 — Bloqueo de EXE
Validación final pendiente.

**Evidencias:**
- `images/20_file_filter_profile.png`
- `images/21_prueba_exe_bloqueado.png`
- `images/22_log_exe_bloqueado.png`

### Prueba 09 — Protección DoS
Validación final pendiente.

**Evidencias:**
- `images/23_dos_policy.png`
- `images/24_prueba_dos.png`
- `images/25_log_dos.png`

---

## 📸 Capturas de pantalla

```text
images/
├── 01_topologia_gns3.png
├── 02_interfaces_fortigate.png
├── 03_vlans_fortigate.png
├── 04_switch_vlans_trunk.png
├── 05_switch_port_security.png
├── 06_dhcp_vlan10.png
├── 07_firewall_policies.png
├── 08_ips_sqli_profile.png
├── 09_custom_signature_sqli.png
├── 10_file_filter_exe.png
├── 11_dos_policy.png
├── 12_prueba_dhcp_usuario.png
├── 13_prueba_internet_nat.png
├── 14_prueba_usuario_web_https.png
├── 15_prueba_usuario_db_bloqueado.png
├── 16_prueba_web_db_mysql.png
├── 17_prueba_web_db_otros_bloqueados.png
├── 18_sqli_attack_detected.png
├── 19_sqli_quarantine_monitor.png
├── 20_file_filter_profile.png
├── 21_prueba_exe_bloqueado.png
├── 22_log_exe_bloqueado.png
├── 23_dos_policy.png
├── 24_prueba_dos.png
└── 25_log_dos.png
```

---

## 📁 Archivos del repositorio

```text
FortiGate-Security-Lab-2174/
├── README.md
├── images/
├── files/
│   ├── fortigate-running-config.conf
│   ├── switch-running-config.txt
│   └── README.md
└── scripts/
    ├── db-setup.sql
    ├── prueba2174.c
    └── test-commands.sh
```

---

## ⚠️ Limitaciones observadas

La configuración de Full SSL Inspection quedó creada, pero durante la comprobación TLS el cliente siguió observando el certificado autofirmado original del WEB Server.

Para validar de forma reproducible la firma IPS, el bloqueo y la cuarentena se utilizó una policy HTTP temporal exclusivamente para la demostración. Esta policy queda deshabilitada en el estado final.

---

## 📝 Estado del proyecto

**Configuración principal:** completada.

**Validaciones realizadas:**
- HTTPS hacia WEB
- bloqueo Usuarios → DB
- WEB → DB en 3306
- bloqueo de otros protocolos WEB → DB
- SQL Injection / IPS
- cuarentena de atacante

**Pendiente:**
- validación final del File Filter `.exe`
- validación DoS
- capturas finales
- exportación de running-configs
- video demostrativo
