# ===============================
# PowerShell Keystore Generator
# ===============================

$KEYSTORE  = "foonote-release-key.jks"
$ALIAS     = "foonote-release-key"
$STOREPASS = "FootNotePass123"
$KEYPASS   = "FootNotePass123"

if (-not (Test-Path $KEYSTORE)) {
    & keytool -genkeypair `
        -v `
        -keystore $KEYSTORE `
        -alias $ALIAS `
        -keyalg RSA `
        -keysize 2048 `
        -validity 10000 `
        -storepass $STOREPASS `
        -keypass $KEYPASS `
        -dname "CN=FootNote, OU=Dev, O=FootNote, L=Sturgeon Falls, ST=ON, C=Canada"

    Write-Host "✅ Keystore created: $KEYSTORE"
} else {
    Write-Host "⚠️ Keystore already exists: $KEYSTORE"
}
