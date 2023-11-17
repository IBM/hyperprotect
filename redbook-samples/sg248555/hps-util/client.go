package main

import (
	"context"
	"crypto/tls"
	"fmt"
	"os"

	pb "github.com/IBM-Cloud/hpcs-grep11-go/grpc"
	"github.com/IBM-Cloud/hpcs-grep11-go/util"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)

var (
	Address     = os.Getenv("HPCS_ADDRESS")
	APIKey      = os.Getenv("HPCS_KEY")
	IAMEndpoint = "https://iam.cloud.ibm.com"
)

type CryptoClient struct {
	conn         *grpc.ClientConn
	Context      context.Context
	CryptoClient pb.CryptoClient
}

// Close HPCS connection
func (cc CryptoClient) Close() {
	cc.conn.Close() //#nosec G104
}

// create a new connected HPCS crypto client from environment variables
// HPCS_ADDRESS and HPCS_KEY
// panics on connection errors
func NewCryptoClient() CryptoClient {
	callOpts := []grpc.DialOption{
		grpc.WithTransportCredentials(credentials.NewTLS(&tls.Config{MinVersion: tls.VersionTLS12})),
		grpc.WithPerRPCCredentials(&util.IAMPerRPCCredentials{
			APIKey:   APIKey,
			Endpoint: IAMEndpoint,
		}),
	}
	conn, err := grpc.Dial(Address, callOpts...)
	if err != nil {
		panic(fmt.Errorf("could not connect to server: %s", err))
	}

	return CryptoClient{
		conn:         conn,
		Context:      context.Background(),
		CryptoClient: pb.NewCryptoClient(conn),
	}
}
