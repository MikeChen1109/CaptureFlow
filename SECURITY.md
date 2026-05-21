# Security Policy

CaptureFlow is a local-first app and does not currently include a backend, account system, payment integration, or cloud sync.

## Supported Versions

Security fixes are handled on the default branch while the project is pre-release.

## Reporting a Vulnerability

Please do not open a public issue for sensitive reports. Contact the maintainer privately with:

- A short description of the issue
- Steps to reproduce
- Affected files or flows
- Any relevant screenshots or logs

The maintainer will confirm receipt, assess impact, and coordinate a fix before public disclosure when needed.

## Current Security Boundaries

- Captured images are intended to remain local.
- EventKit access is limited to creating reminders and calendar events from user-approved actions.
- No third-party network AI provider is connected.
- Any future cloud, account, analytics, payment, or AI integration should document what data leaves the device.
