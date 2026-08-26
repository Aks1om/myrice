# Local profiles

Put machine-specific profile fragments here as `*.json`. They are ignored by
Git so they can name local choices without being published. Do not put secrets
in profiles.

Copy `example.json.example` to a new `.json` file, adjust only explicit stages
and capabilities, then use it with:

```bash
./bootstrap.sh plan --profile profiles/local/workstation.json
./bootstrap.sh bootstrap --profile profiles/local/workstation.json
```

The base profile never enables system, boot, SDDM, Wi-Fi, or laptop settings.
Every dangerous stage must enable its matching capability; for example,
`"stages": ["services"]` requires `"laptop_services": true`.
