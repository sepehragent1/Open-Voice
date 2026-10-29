<div align="center">

[🇬🇧 English](README.en.md) | [🇮🇷 فارسی](README.md)

</div>

# Open Voice

**A lightweight, self-hosted peer-to-peer voice chat application.**

Open Voice is an open-source voice chat project built with Flutter and WebRTC, inspired by the simplicity of Discord voice channels. It is designed to let users communicate directly with each other without relying on a centralized voice hosting service.

The project allows you to host your own room, invite other users, and establish voice connections using WebRTC.

**Repository:** [sepehragent1/Open-Voice](https://github.com/sepehragent1/Open-Voice)  
**Downloads:** [GitHub Releases](https://github.com/sepehragent1/Open-Voice/releases)

## Features

- **Peer-to-peer voice communication:** Uses WebRTC to establish audio connections between participants.
- **Self-hosted rooms:** Host a room using the Windows application.
- **Cross-platform support:** Available for Windows and Android.
- **Flutter-based:** The application is built with Flutter.
- **NAT traversal support:** STUN/TURN configuration can help establish connections across different networks.
- **Secure media transport:** WebRTC uses DTLS-SRTP to protect media connections.
- **Password protection:** Room authentication can use Argon2id for password hashing, where implemented by the application.

## Important: Before You Start

Open Voice uses a self-hosted signaling architecture. Before hosting a room, make sure you understand the following requirements.

### 1. The host must run the Windows application

The Windows application acts as the local signaling server for the room. The host must keep the application running while other users connect.

The signaling server helps participants discover and establish connections with each other. Voice traffic can then travel directly between participants when the network allows it.

### 2. Hosting from outside your local network requires network configuration

If you want people outside your home network to join your room, you may need to:

- Find your public IP address.
- Allow the required port through Windows Firewall.
- Configure port forwarding on your router.
- Make sure your internet connection has a publicly reachable IP address.

**Important:** If your ISP uses Carrier-Grade NAT (CGNAT), router port forwarding alone may not work. You may need a public IP address or a properly configured external TURN server.

### 3. TURN is recommended for difficult network conditions

Some networks, especially mobile networks, restrictive Wi-Fi networks, and CGNAT connections, may prevent direct peer-to-peer connections.

A TURN server can relay WebRTC traffic when a direct connection cannot be established. This can improve connectivity, but it requires a reachable TURN server and valid configuration.

---

## Download and Install

Download the appropriate release from the [GitHub Releases page](https://github.com/sepehragent1/Open-Voice/releases).

### Windows

Depending on the available release assets, you can use either of the following:

- **Setup installer:** Download and run the Windows setup executable.
- **Portable version:** Download the portable ZIP archive, extract it, and run the application executable.

#### Windows SmartScreen warning

Windows may display a Microsoft Defender SmartScreen warning if the application is not widely recognized or does not have a trusted code-signing certificate.

Only run the application if you downloaded it from the official Open Voice repository and trust the source. Do not bypass security warnings for files from unknown sources.

### Android

1. Download the Android APK from the official releases page.
2. Open the downloaded APK on your device.
3. If prompted, allow installation from that source in your Android settings.
4. Complete the installation and launch Open Voice.

Android may warn you when installing an APK outside the Play Store. Verify that the APK came from the official project release before installing it.

---

## Hosting a Room on Windows

### Step 1: Start the application

Launch Open Voice on the Windows computer that will host the room.

### Step 2: Start the room or signaling server

Use the application's room-hosting controls to start hosting. The host must keep the application running for the duration of the session.

The signaling server uses port `8080` by default in the setup described below. If your application uses a different port, replace `8080` with the configured value throughout these instructions.

### Step 3: Allow the port through Windows Firewall

Open **Command Prompt as Administrator** and run:

```bat
netsh advfirewall firewall add rule name="Open Voice TCP 8080" dir=in action=allow protocol=TCP localport=8080
```

If the application also requires UDP traffic on this port, add:

```bat
netsh advfirewall firewall add rule name="Open Voice UDP 8080" dir=in action=allow protocol=UDP localport=8080
```

Only open the protocols and ports actually required by your application's signaling and networking configuration. WebSocket-based signaling normally uses TCP; WebRTC media and TURN traffic may use different ports.

### Step 4: Configure router port forwarding

To allow users outside your local network to reach the signaling server, sign in to your router's administration panel.

Find the section usually named **Port Forwarding**, **Virtual Server**, or **NAT**.

Create a rule with the following settings:

| Setting | Value |
|---|---|
| Name | Open Voice |
| Internal IP address | The host computer's local IPv4 address |
| External port | `8080` |
| Internal port | `8080` |
| Protocol | TCP, if required by the signaling server |

If the application requires additional protocols or ports, configure them according to the actual implementation.

It is recommended to assign the host computer a reserved local IP address through your router's DHCP settings so that the forwarding rule does not break when the address changes.

### Step 5: Share the connection information

Find your public IP address and provide the connection information required by Open Voice to the people you want to invite.

Do not share your router administrator password or other private credentials.

**Security note:** Exposing a port makes a service reachable from outside your network. Only expose the ports the application needs, and keep the application updated.

---

## TURN Server Setup (Optional)

A TURN server can relay WebRTC traffic when two participants cannot establish a direct connection.

You can use a hosted TURN provider or configure your own server. Self-hosting TURN requires a publicly reachable server and appropriate firewall and network configuration.

### Example: Install Coturn on Ubuntu

On an Ubuntu server, install Coturn:

```bash
sudo apt update
sudo apt install coturn
```

Open the configuration file:

```bash
sudo nano /etc/turnserver.conf
```

A basic configuration example is shown below:

```ini
listening-port=3478
fingerprint
lt-cred-mech
realm=your-domain.example
user=openvoiceuser:REPLACE_WITH_A_STRONG_PASSWORD
```

Replace the example domain and password with your own values. This is a starting point, not a complete production configuration. Depending on your server's network topology, you may also need to configure its external IP address, relay port range, TLS settings, and authentication.

Enable and start the service:

```bash
sudo systemctl enable coturn
sudo systemctl restart coturn
sudo systemctl status coturn
```

Configure the server firewall and any upstream firewall or router to permit the ports required by your Coturn configuration. The default listening port shown above is `3478`; relay traffic may use a separate UDP port range.

For production deployments, use a secure configuration and avoid exposing an unauthenticated open relay.

### Configure TURN in Open Voice

Enter the values supported by the application's TURN configuration interface:

| Field | Description |
|---|---|
| TURN URL | The TURN server address and transport, such as `turn:turn.example.com:3478` |
| Username | The TURN authentication username |
| Password | The TURN authentication credential |

The exact field names and accepted URL formats depend on the implementation. Use the formats expected by the version of Open Voice you are running.

A TURN server is not the same as the signaling server. They serve different purposes, and configuring one does not automatically configure the other.

---

## Build from Source

If you want to compile Open Voice yourself, install the required development tools first:

- Flutter SDK
- Dart SDK (included with Flutter)
- Git
- Android SDK and the required Android build tools for Android builds
- The Windows development toolchain required by Flutter for Windows builds

Clone the repository:

```bash
git clone https://github.com/sepehragent1/Open-Voice.git
cd Open-Voice
```

Install dependencies:

```bash
flutter pub get
```

Check your development environment:

```bash
flutter doctor
```

### Run the application

For Windows:

```bash
flutter run -d windows
```

For Android, connect a device with USB debugging enabled or start an Android emulator:

```bash
flutter devices
flutter run -d <device_id>
```

Replace `<device_id>` with the device identifier reported by Flutter.

### Build for Windows

```bash
flutter build windows --release
```

The release build is normally generated under:

```text
build/windows/x64/runner/Release/
```

The exact output directory can vary with the Flutter version and build configuration.

### Build an Android APK

```bash
flutter build apk --release
```

The APK is normally generated at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

For distribution, test the release build on real devices and verify that all required assets, permissions, and networking settings work correctly.

---

## Security and Privacy

Open Voice uses WebRTC for peer-to-peer communication.

- **DTLS-SRTP:** WebRTC uses DTLS-SRTP to protect media in transit between peers.
- **Password hashing:** Argon2id is designed for password hashing and can help protect stored password verifiers when correctly implemented.
- **Self-hosting:** Hosting your own signaling server gives you control over that part of the connection infrastructure.

Keep in mind that transport encryption does not automatically guarantee end-to-end security for every part of an application. Signaling, authentication, server configuration, credential handling, and any relayed traffic must also be implemented and configured correctly.

Do not publish private TURN credentials, passwords, API keys, or other secrets in source code or public repositories.

---

## Troubleshooting

### Other users cannot connect to my room

Check the following:

1. Confirm that Open Voice is running on the host computer.
2. Verify that the signaling server is listening on the expected port.
3. Check Windows Firewall rules.
4. Confirm that router port forwarding points to the correct local IP address.
5. Verify that your ISP provides a publicly reachable IP address and that CGNAT is not preventing inbound connections.

### Users on mobile networks cannot connect

Mobile networks often use CGNAT or restrictive NAT configurations.

Try configuring a reachable TURN server and ensure that the necessary TURN ports are open. A TURN server must be accessible from the participants' networks to help relay their traffic.

### Local connections work, but external connections fail

This often indicates a problem with port forwarding, the host's firewall, the public IP address, or ISP-level NAT.

Test the connection from a network outside the host's local network. Testing a public address from inside the same network may fail on routers that do not support NAT loopback.

### Voice connections fail even though the room is reachable

Successful signaling does not necessarily mean that the WebRTC media connection can be established.

Check the ICE connection state, STUN/TURN configuration, firewall restrictions, and whether a TURN relay is available when direct connectivity fails.

### The Windows application does not start

- Check whether Windows blocked the downloaded file.
- Make sure you downloaded a complete release archive or installer.
- Try downloading the release again from the official repository.
- If building from source, run `flutter doctor` and review the build output for missing dependencies.

---

## Contributing

Contributions, bug reports, and suggestions are welcome.

If you want to contribute:

1. Fork the repository.
2. Create a branch for your change.
3. Make and test your changes.
4. Submit a pull request describing what changed and why.

For bug reports, include relevant logs, your operating system, the application version, and the steps needed to reproduce the issue. Avoid including passwords, private IP information that you do not wish to share, or TURN credentials.

## Support and Issues

For bug reports, feature requests, and technical discussions, visit the official repository:

[**Open Voice on GitHub**](https://github.com/sepehragent1/Open-Voice)

---

<div align="center">

**Open Voice — Your room. Your connections. Your voice.**

</div>
