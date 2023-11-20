package main

import (
	"encoding/base64"
	"fmt"
)

func Encode(raw []byte) string {
	return base64.StdEncoding.EncodeToString(raw)
}

func Decode(encoded string) []byte {
	raw, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		panic(fmt.Errorf("decoding error: %s", err))
	}
	return raw
}
