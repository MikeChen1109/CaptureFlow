# Security Policy

CaptureFlow is a local-first app. Security reports should focus on user content, local storage, external provider requests, and action creation flows.

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
- Default provider-backed vision can send image data to the configured external LLM provider.
- Default provider-backed analyze/generation can send screenshot-derived text context to the configured external LLM provider unless the user selects Apple Foundation Models on a supported iOS 26+ Apple Intelligence device.
- OpenAI API keys are supplied by integrators outside the app UI and must not be committed or written to plaintext files.
- Any new integration that sends user content off device should document what data is sent and why.
