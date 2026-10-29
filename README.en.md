 <div align="center">

[🇮🇷 فارسی](README.md) | [🇬🇧 English](README.en.md)

</div>

# 🎙️ Open Voice

**A lightweight, self-hosted P2P voice chat application.**

[![GitHub Repository](https://img.shields.io/badge/GitHub-Repository-181717?logo=github)](https://github.com/sepehragent1/Open-Voice)
[![Flutter](https://img.shields.io/badge/Flutter-Powered-02569B?logo=flutter)](https://flutter.dev/)
[![WebRTC](https://img.shields.io/badge/Communication-WebRTC-333333)](https://webrtc.org/)

---

## 📖 About the Project

**Open Voice** is a peer-to-peer (P2P) voice chat application developed using Flutter and WebRTC, inspired by applications such as Discord.

The goal of this project is to provide a simple way for users to communicate by voice without relying on a permanent centralized server to manage every aspect of their communication.

In the Open Voice architecture, the host computer acts as a local **Signaling Server**, while users rely on WebRTC to establish connections with one another. When a direct connection is possible, audio can travel directly between participants. Some network environments may require a TURN server.

### ✨ Key Features

- 🎙️ Voice communication using WebRTC
- 🔗 Peer-to-peer connections whenever possible
- 🖥️ Room hosting through the Windows application
- 📱 Android application support
- 🏠 Self-hosted architecture without a permanent centralized room-management server
- 🔐 Security technologies for protecting voice communication and passwords
- 🪶 Lightweight design built with Flutter
- 🌐 Connect users across different locations through the internet

> **Note:** P2P does not mean the application can operate without any server in every situation. Initial connection setup requires signaling, and a TURN server may be necessary to relay media under certain network conditions.

## 📋 Table of Contents

- [Critical Requirements](#-critical-requirements)
- [Installation Guide](#-installation-guide)
- [Hosting a Voice Room](#-hosting-a-voice-room)
- [Network Configuration and Port Forwarding](#-network-configuration-and-port-forwarding)
- [Setting Up a TURN Server](#-setting-up-a-turn-server)
- [Development and Building from Source](#-development-and-building-from-source)
- [Security Considerations](#-security-considerations)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)

---

## ⚠️ Critical Requirements

Please read these requirements carefully before installing the application and hosting a room. Without the necessary configuration, other users may not be able to connect.

### 1. The Host Must Use the Windows Application

The person creating the room, referred to as the **Host**, must run the Windows version of Open Voice.

The Windows application acts as the local **Signaling Server**, exchanging the information required to establish connections between participants.

Therefore, the Android application alone cannot be used to host a room.

### 2. Access to Your Router's Administration Panel

The host must have access to their router's administration panel to configure **Port Forwarding**.

If port forwarding is not configured correctly, users outside the host's local network may be unable to reach the Signaling Server.

### 3. Check Your Public IP Address and CGNAT Status

To allow users to connect over the internet, the host must check their public IP address and network configuration.

A publicly reachable IPv4 address is important for the usual port-forwarding method. If the host's internet connection uses Carrier-Grade NAT (CGNAT), configuring port forwarding on the router alone is generally insufficient.

Depending on the application's architecture and network configuration, you may need an alternative solution, such as obtaining a public IPv4 address from your internet service provider or using a TURN server.

### 4. A TURN Server Is Recommended for Mobile Networks

Using a TURN server is **strongly recommended** for users connecting through mobile internet, particularly on networks that use CGNAT.

TURN can relay media through an intermediary server when a direct WebRTC connection cannot be established.

> **Note:** A TURN server does not automatically replace the Signaling Server. These services have different responsibilities.

---

## 📥 Installation Guide

### 🖥️ Installing the Windows Version

The Windows version is required for hosting rooms. Depending on the files available in the project's Releases section, choose one of the following installation methods.

**Method 1: Setup.exe**

1. Visit the [project's GitHub Releases page](https://github.com/sepehragent1/Open-Voice/releases).
2. Open the latest release.
3. Download the Windows installer with the `.exe` extension.
4. Run the setup file and follow the installation instructions.
5. Launch Open Voice after installation.

**Method 2: Portable Version**

1. Download the Portable ZIP archive from the Releases page.
2. Extract the archive into a folder.
3. Run the application executable from the extracted folder.

The portable version does not require a separate installation process.

#### Windows SmartScreen Warning

Windows may display a warning that the publisher is unknown or that the file's reputation has not been established. This warning does not necessarily mean the application is malicious, but it should not be ignored without checking the source.

If you downloaded the file from the official project repository and trust its source, you may see the following options:

1. Click **More info**.
2. Select **Run anyway**.

Only proceed if you have verified that the file came from a source you trust.

### 📱 Installing the Android Version

1. Visit the [GitHub Releases page](https://github.com/sepehragent1/Open-Voice/releases).
2. Download the Android APK.
3. Open the APK on your Android device.
4. If prompted, enable installation from that source in Android settings.
5. If Google Play Protect displays a warning, review the details before deciding whether to continue.
6. Complete the installation and launch the application.

It is recommended to download the APK only from the official project repository or another trusted release source.

**Note:** The Android version is intended for joining rooms. Hosting a room still requires the Windows version.

---

## 🏠 Hosting a Voice Room

This section is for users who want to create a room and allow other participants to connect.

### Step 1: Launch the Windows Application

Run Open Voice on your Windows computer.

The host computer must remain powered on, and the hosting application must continue running while the room is in use. Shutting down the computer or stopping the Signaling Server may prevent new users from connecting and, depending on the implementation, may also disrupt existing connections.

### Step 2: Configure the Port

In the hosting or signaling settings, set the port to:

`8080`

This port must be consistent across the application, Windows Firewall, and router configuration.

### Step 3: Find Your Computer's Local IP Address

Open Command Prompt in Windows and run:

```cmd
ipconfig
```

In the output, locate the IPv4 address of the network adapter connected to your router.

For example:

```text
IPv4 Address . . . . . . . . . . : 192.168.1.100
```

In this example, `192.168.1.100` is the computer's local IP address. Your actual address may be different.

It is recommended to create a DHCP reservation for the host computer in your router settings so that its local IP address does not change.

### Step 4: Find Your Public IP Address

You can use a trusted IP-checking service to view your public IP address. For example:

[https://ifconfig.me](https://ifconfig.me)

If you have a usable public IPv4 address, the displayed address is generally the one external users need to reach your host.

However, if your network uses CGNAT or another router exists upstream, ordinary port forwarding may not work.

### Step 5: Share the Connection Information

After configuring your network, provide participants with the information required to connect.

The connection details must match the connection method and fields provided by the version of Open Voice you are using. For example, if the application asks for a server address and port, participants must enter the host's publicly reachable address and the correct port.

**Security note:** Never publish login information, passwords, or other confidential data in the public GitHub repository or public messages.

---

## 🌐 Network Configuration and Port Forwarding

To allow users on external networks to connect, incoming traffic must be forwarded to the host computer.

This guide assumes that the signaling port is `8080`.

### 1. Configure Windows Firewall

Windows Firewall may block incoming connections. To allow TCP and UDP traffic on port 8080, open Command Prompt **as Administrator**.

Run the following commands:

**Allow TCP connections**

```cmd
netsh advfirewall firewall add rule name="Open Voice TCP 8080" dir=in action=allow protocol=TCP localport=8080
```

**Allow UDP connections**

```cmd
netsh advfirewall firewall add rule name="Open Voice UDP 8080" dir=in action=allow protocol=UDP localport=8080
```

These commands create inbound firewall rules. They do not guarantee that the application is listening on both protocols.

If the Signaling Server uses TCP only, the UDP rule will not help that service. If the application uses additional ports or protocols for WebRTC communication, configure the appropriate rules for the actual implementation.

To remove these rules later, run:

```cmd
netsh advfirewall firewall delete rule name="Open Voice TCP 8080"
netsh advfirewall firewall delete rule name="Open Voice UDP 8080"
```

> **Security recommendation:** Create only the firewall rules required by the application instead of disabling Windows Firewall entirely.

### 2. Configure Port Forwarding on Your Router

Sign in to your router's administration panel. The address varies by router model and is often available through the router documentation or the Default Gateway shown by `ipconfig`.

Look for a section named something like:

- Port Forwarding
- Virtual Server
- NAT
- Port Mapping

Create a new rule using the following settings:

| Setting | Value |
|---|---|
| Service Name | Open Voice |
| External Port | `8080` |
| Internal Port | `8080` |
| Internal IP | The host computer's local IPv4 address |
| Protocol | TCP and UDP, if required by the application |
| Status | Enabled |

For example, if the host computer's local address is `192.168.1.100`, incoming traffic on port 8080 should be forwarded to that address on port 8080.

If your router does not allow TCP and UDP to be selected together, create separate rules.

After saving the settings, make sure the host computer's local IP address has not changed.

### 3. Verify the Configuration

To check whether a TCP service is listening on port 8080, run the following command in PowerShell:

```powershell
Get-NetTCPConnection -State Listen -LocalPort 8080
```

If no results appear, the service may not be running or may be using a different port.

You can also test the connection from a device outside the host's local network. Testing your public address from within the same network is not always reliable because some routers do not support NAT loopback.

**Important:** An open firewall port or a router forwarding rule does not, by itself, prove that the service is reachable over the internet. The service must be running, the network path must be configured correctly, and CGNAT must not be preventing inbound access.

---

## 🔄 Setting Up a TURN Server

### What Is TURN, and Why Is It Needed?

WebRTC attempts to find a suitable network path between two devices. In many network environments, a direct P2P connection works. However, NAT and CGNAT can prevent a direct connection on some networks, particularly mobile networks.

In these situations, **TURN** can relay media traffic through an intermediary server.

For example, a host may be reachable through a home internet connection while a participant using mobile internet cannot establish a suitable direct path. If the application and network configuration support it, TURN may resolve the media connectivity problem.

### Step 1: Prepare a Server

You need an Ubuntu system or a WSL environment with the necessary permissions to install and run Coturn.

To install Coturn on Ubuntu:

```bash
sudo apt update
sudo apt install coturn
```

In WSL, check network access, IP addressing, firewall rules, and external reachability separately. Installing Coturn in WSL does not automatically make the server accessible over the internet.

For reliable public access, a server with a public IP address and an appropriate network configuration is generally a better choice.

### Step 2: Run Coturn

The following command is an example of running Coturn with the settings used in this guide:

```bash
sudo turnserver -n -a -u myuser:mypassword -r myrealm -p 5349 -L 0.0.0.0 --min-port 49152 --max-port 65535
```

Important parameters:

| Parameter | Description |
|---|---|
| `-n` | Run without reading a configuration file |
| `-a` | Enable authentication |
| `-u` | Set the username and password |
| `-r` | Set the authentication realm |
| `-p 5349` | Set the TURN listening port |
| `-L 0.0.0.0` | Listen on all local IPv4 addresses |
| `--min-port` | Set the minimum relay port |
| `--max-port` | Set the maximum relay port |

In this example, `myuser`, `mypassword`, and `myrealm` are placeholders. Replace them with appropriate values for your environment.

For public use, choose a strong password and never commit confidential credentials to a public repository.

### Step 3: Open the TURN Ports

Port `5349` is the TURN listening port in this configuration. Ports `49152` through `65535` are the configured relay port range.

For internet access, the listening port and relay port range must be allowed by the server firewall and, if NAT is present, by the relevant router or network firewall. The required protocols depend on your configuration.

In this example, the listening port is set to 5349. This does **not** automatically mean that TURN over TLS is enabled. TLS requires the appropriate certificate, server configuration, and client connection URI.

For reliable public access, also check:

- The server's public address and NAT configuration
- Firewall rules and cloud security groups
- Access to the relay port range
- Coturn's external IP configuration when NAT is involved
- Client support for the selected protocol and connection method

### Step 4: Enter the TURN Configuration in Open Voice

In the application's **TURN Config** section, enter the required values. The exact field names may differ between application versions.

| Field | Example |
|---|---|
| TURN Server / Host | `turn:YOUR_PUBLIC_IP:5349` |
| Username | The username configured for TURN |
| Password | The password configured for TURN |

The example above uses a TURN URI with UDP as the default transport. The URI, protocol, and fields must match the WebRTC implementation used by your version of Open Voice.

**Important:** Entering TURN credentials into the application is not sufficient on its own. The server must be running, its ports must be reachable, and the client and server configurations must be compatible. Test server accessibility first, then test voice communication.

---

## 🛠️ Development and Building from Source

Open Voice is built with Flutter. To contribute to development, you need the Flutter SDK, the tools required by your target platform, and the project source code.

Official repository:

[https://github.com/sepehragent1/Open-Voice](https://github.com/sepehragent1/Open-Voice)

### Development Requirements

- Flutter SDK compatible with the project
- Dart SDK compatible with Flutter
- Git
- Android SDK for building the Android version
- Visual Studio with the **Desktop development with C++** workload for building the Windows version

Check the project's configuration files for the required Flutter version and other dependencies.

### Step 1: Clone the Repository

```bash
git clone https://github.com/sepehragent1/Open-Voice.git
cd Open-Voice
```

### Step 2: Install Dependencies

```bash
flutter pub get
```

This command downloads the dependencies declared in `pubspec.yaml`.

### Step 3: Check Your Development Environment

```bash
flutter doctor
```

Review the output and resolve any issues involving SDKs, compilers, or target platform tools.

### Step 4: Run the Windows Version

```bash
flutter run -d windows
```

Windows desktop support must be enabled in Flutter, and the required Windows build tools must be installed.

### Step 5: Build the Android Release APK

```bash
flutter build apk --release
```

If the build succeeds, Flutter normally creates the APK at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

This is Flutter's default output path. If the project build configuration has been modified, the output location may differ.

### Other Useful Commands

Analyze the source code:

```bash
flutter analyze
```

Run tests, if available:

```bash
flutter test
```

List available devices:

```bash
flutter devices
```

To suggest improvements, fix bugs, or add features, you can fork the repository and submit a pull request.

---

## 🔐 Security Considerations

### Secure Media and Password Handling

Open Voice uses WebRTC for peer-to-peer communication.

WebRTC supports DTLS-SRTP to protect media in transit. Password security depends on the application's actual authentication and password-storage implementation.

The security of the application also depends on signaling, credential handling, server configuration, and network exposure.

### Security Recommendations for Hosts

- Open only the ports required by the application.
- Use strong passwords for accounts and TURN services.
- Never publish passwords or confidential credentials in the public repository.
- Obtain software and dependencies from trusted sources.
- Do not expose a public TURN relay without appropriate authentication and access controls.
- Consider usage limits and access restrictions when operating a public server.

> **Note:** Media encryption does not guarantee complete anonymity, hide every user's IP address, or secure every component of the system. P2P communication and network configuration may expose information such as IP addresses to other participants.

---

## 🧰 Troubleshooting

### Issue 1: Users Cannot Connect to the Room

Check the following:

1. The Windows application is running on the host computer.
2. The port configured in the application matches the firewall and router settings.
3. The host computer's local IP address has not changed.
4. Port-forwarding rules point to the correct address.
5. The host's internet connection is active.
6. The host is not behind CGNAT, or an appropriate alternative has been configured.

### Issue 2: The Connection Works, but There Is No Audio

Successful signaling does not necessarily mean that the media path is working.

Check the following:

- Microphone permissions in Windows and Android
- Correct audio input and output devices
- Whether the microphone is muted
- WebRTC configuration and media negotiation
- ICE candidate errors
- TURN server accessibility, if used
- Relay port availability and TURN configuration compatibility

If participants use mobile internet or restricted networks, a correctly configured TURN server may resolve media connectivity issues.

### Issue 3: Users Cannot Connect over Mobile Internet

Some mobile operators use CGNAT, which can limit direct connections between devices.

In this situation:

1. Test the connection using a different network.
2. Make sure the TURN server is accessible over the internet.
3. Verify the TURN configuration values.
4. Check the listening port and relay port range.
5. Review Coturn and WebRTC logs for errors.

If TURN is incorrectly configured, simply enabling the TURN option in the application will not solve the problem.

### Issue 4: The Connection Drops After Some Time

Disconnections can have several causes:

- The host application closes.
- The host computer shuts down or loses internet access.
- The network or IP address changes.
- The WebRTC connection expires or its network path changes.
- NAT or firewall restrictions interfere with the connection.
- A participant's internet connection becomes unstable.
- The TURN server stops running.

First, determine whether the Signaling Server is still running and whether the media connection has also failed. Application and server logs can help identify the cause.

### Issue 5: Local Connections Work, but External Connections Fail

This usually indicates a problem with external network access.

Check for:

- Incorrect port forwarding
- An incorrect local IP address
- CGNAT
- A second router or double NAT
- Firewall restrictions
- A router that does not support NAT loopback when testing the public IP from inside the same network

For a reliable external connectivity test, use a device connected to a different network.

### Issue 6: Flutter Commands Fail

If Flutter commands return errors, run:

```bash
flutter doctor
flutter pub get
```

Review the output. Problems involving SDKs, dependencies, permissions, or build tools are often identified at this stage.

### Issue 7: The TURN Server Runs, but Connections Still Fail

Check the following:

- Username, password, and realm
- Public server address
- TURN listening port
- Firewall and NAT rules
- Relay port range
- Compatibility between the client and server protocols
- TLS settings, if applicable

Also remember that successfully reaching the listening port does not necessarily mean the relay ports are accessible.

---

## 🤝 Contributing

Open Voice welcomes contributions that help improve the project.

If you want to contribute:

1. Fork the repository.
2. Make your changes in a separate branch.
3. Review and test your changes where possible.
4. Commit your changes.
5. Submit a pull request with a clear explanation of what changed and why.

When reporting a bug, include:

- Your operating system and application version
- Steps to reproduce the issue
- Expected and actual behavior
- Relevant error messages or logs
- The type of network being used, if relevant

Avoid including passwords, other people's private IP information, authentication credentials, or other sensitive data in public reports.

---

## 💬 Final Notes

Open Voice aims to provide a lightweight, self-hosted voice chat experience. It uses direct P2P connections whenever possible and requires signaling to establish connections between participants.

For a successful setup, prioritize these three requirements:

- The host must run the Windows application.
- Firewall and port-forwarding rules must be configured correctly.
- TURN should be configured for networks where direct WebRTC connections cannot be established.

Thank you for checking out Open Voice and taking an interest in the project.

**Official repository:** [sepehragent1/Open-Voice](https://github.com/sepehragent1/Open-Voice)

