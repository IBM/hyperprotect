package main

import (
	"bytes"
	"encoding/base64"
	"os"
	"os/exec"
	"strings"
)

// Encrypts the payload with the password using the openssl cli tool
func EncryptWithPassword(pass []byte, input []byte) (string, error) {

	file, err := os.CreateTemp("", "cleartext")
	if err != nil {
		return "", err
	}
	defer os.Remove(file.Name())

	if err := os.WriteFile(file.Name(), input, 0600); err != nil {
		return "", err
	}

	var pwdBuffer bytes.Buffer
	pwdCmd := exec.Command("openssl", "enc", "-aes-256-cbc", "-pbkdf2", "-pass", "stdin", "-in", file.Name()) //#nosec G204
	pwdCmd.Stdin = strings.NewReader(string(pass))
	pwdCmd.Stdout = &pwdBuffer

	if err := pwdCmd.Run(); err != nil {
		return "", err
	}

	return base64.StdEncoding.EncodeToString(pwdBuffer.Bytes()), nil
}

// Decrypts the payload with the password using the openssl cli tool
func DecryptWithPassword(pass []byte, input string) ([]byte, error) {

	file, err := os.CreateTemp("", "cleartext")
	if err != nil {
		return nil, err
	}
	defer os.Remove(file.Name())

	decodedInput, err := base64.StdEncoding.DecodeString(input)
	if err != nil {
		return nil, err
	}

	if err := os.WriteFile(file.Name(), decodedInput, 0600); err != nil {
		return nil, err
	}

	var pwdBuffer bytes.Buffer

	pwdCmd := exec.Command("openssl", "aes-256-cbc", "-d", "-pbkdf2", "-pass", "stdin", "-in", file.Name()) //#nosec G204
	pwdCmd.Stdin = strings.NewReader(string(pass))
	pwdCmd.Stdout = &pwdBuffer

	if err := pwdCmd.Run(); err != nil {
		return nil, err
	}

	return pwdBuffer.Bytes(), nil
}
