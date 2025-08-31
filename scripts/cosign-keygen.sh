#!/bin/bash

# Cosign Key Generation Script for Aegis Framework
# This script generates and manages Cosign keys for image signing

set -e

KEY_DIR="./keys"
COSIGN_PASSWORD_FILE="./cosign.password"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if cosign is installed
check_cosign() {
    if ! command -v cosign &> /dev/null; then
        log_error "cosign is not installed. Please install it first:"
        log_error "https://docs.sigstore.dev/cosign/installation/"
        exit 1
    fi
}

# Generate password file
generate_password() {
    if [ ! -f "$COSIGN_PASSWORD_FILE" ]; then
        log_info "Generating password file..."
        openssl rand -base64 32 > "$COSIGN_PASSWORD_FILE"
        chmod 600 "$COSIGN_PASSWORD_FILE"
        log_warn "Password file created: $COSIGN_PASSWORD_FILE"
        log_warn "Keep this file secure and backup it!"
    else
        log_info "Password file already exists"
    fi
}

# Generate key pair
generate_keys() {
    if [ ! -d "$KEY_DIR" ]; then
        mkdir -p "$KEY_DIR"
        chmod 700 "$KEY_DIR"
    fi

    if [ ! -f "$KEY_DIR/cosign.key" ]; then
        log_info "Generating Cosign key pair..."
        cosign generate-key-pair --output-file "$KEY_DIR/cosign" < "$COSIGN_PASSWORD_FILE"
        log_info "Key pair generated successfully"
        log_warn "Private key: $KEY_DIR/cosign.key"
        log_warn "Public key: $KEY_DIR/cosign.pub"
    else
        log_info "Key pair already exists"
    fi
}

# Show public key
show_public_key() {
    if [ -f "$KEY_DIR/cosign.pub" ]; then
        log_info "Public key for Kyverno policy:"
        echo "-----BEGIN PUBLIC KEY-----"
        cat "$KEY_DIR/cosign.pub"
        echo "-----END PUBLIC KEY-----"
    else
        log_error "Public key not found. Run key generation first."
        exit 1
    fi
}

# Backup keys
backup_keys() {
    BACKUP_DIR="./backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    cp -r "$KEY_DIR" "$BACKUP_DIR/"
    cp "$COSIGN_PASSWORD_FILE" "$BACKUP_DIR/"
    log_info "Keys backed up to: $BACKUP_DIR"
}

# Main menu
main() {
    check_cosign

    echo "Cosign Key Management for Aegis Framework"
    echo "=========================================="
    echo "1. Generate password and keys"
    echo "2. Show public key for Kyverno"
    echo "3. Backup keys"
    echo "4. Exit"
    echo ""

    read -p "Choose an option (1-4): " choice

    case $choice in
        1)
            generate_password
            generate_keys
            ;;
        2)
            show_public_key
            ;;
        3)
            backup_keys
            ;;
        4)
            log_info "Goodbye!"
            exit 0
            ;;
        *)
            log_error "Invalid option"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"