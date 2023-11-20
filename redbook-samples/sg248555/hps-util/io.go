package main

import (
	"encoding/pem"
	"fmt"
	"io"
)

func ReadPem(in io.Reader) ([]byte, error) {
	pemBytes, err := io.ReadAll(in)
	if err != nil {
		return nil, fmt.Errorf("failed to ReadAll from Reader: %w", err)
	}
	pemBlock, _ := pem.Decode(pemBytes)
	if pemBlock == nil {
		return nil, fmt.Errorf("failed to decode PEM input")
	}
	return pemBlock.Bytes, nil
}

func WritePem(out io.Writer, bytes []byte, fileType string) error {
	err := pem.Encode(out, &pem.Block{
		Type:  fileType,
		Bytes: bytes,
	})
	if err != nil {
		return fmt.Errorf("failed writing pem bytes to writer: %w", err)
	}
	return nil
}
