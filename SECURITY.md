# Security

Do not attach real clipboard data, encryption keys, credentials, or private screenshots to reports. Report security issues privately to the repository owner through GitHub's private vulnerability reporting when available.

History and Library data are encrypted locally with AES-GCM. Encryption does not protect decrypted content in the running process. App exclusions and concealed pasteboard markers reduce capture of secrets but cannot identify every password or token; use Pause or Ignore Next Copy when needed.

The Keychain encryption key is device-only. Losing it makes saved data unrecoverable. Failed decryption preserves the existing file and stops further writes for the affected store.
