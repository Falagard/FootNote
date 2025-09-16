# ===============================
# PowerShell Keystore Generator
# ===============================

$KEYSTORE  = "my-release-key.jks"
$ALIAS     = "my-key-alias"
$STOREPASS = "S3cretStorePass"
$KEYPASS   = "S3cretKeyPass"

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
        -dname "CN=Your Name, OU=Dev, O=YourOrg, L=City, ST=State, C=US"

    Write-Host "✅ Keystore created: $KEYSTORE"
} else {
    Write-Host "⚠️ Keystore already exists: $KEYSTORE"
}
