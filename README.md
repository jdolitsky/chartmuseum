# chartmuseum/auth

[![Codefresh build status]( https://g.codefresh.io/api/badges/pipeline/chartmuseum/chartmuseum%2Fauth%2Fmaster?type=cf-1)]( https://g.codefresh.io/public/accounts/chartmuseum/pipelines/chartmuseum/auth/master)
[![Go Report Card](https://goreportcard.com/badge/github.com/chartmuseum/auth)](https://goreportcard.com/report/github.com/chartmuseum/auth)
[![GoDoc](https://godoc.org/github.com/chartmuseum/auth?status.svg)](https://godoc.org/github.com/chartmuseum/auth)

Go library for generating [ChartMuseum](https://github.com/helm/chartmuseum) JWT Tokens, authorizing HTTP requests, etc.

## How to Use

### Generating a JWT token (example)

[Source](./testcmd/getjwt/main.go)

Clone this repo and run `go run testcmd/getjwt/main.go` to run this example

```go
package main

import (
	"fmt"
	"time"

	cmAuth "github.com/chartmuseum/auth"
)

func main() {

	// This should be the private key associated with the public key used
	// in ChartMuseum server configuration (server.pem)
	cmTokenGenerator, err := cmAuth.NewTokenGenerator(&cmAuth.TokenGeneratorOptions{
		PrivateKeyPath: "./testdata/server.key",
	})
	if err != nil {
		panic(err)
	}

	// Example:
	// Generate a token which allows the user to push to the "org1/repo1"
	// repository, and expires in 5 minutes
	access := []cmAuth.AccessEntry{
		{
			Name:    "org1/repo1",
			Type:    cmAuth.AccessEntryType,
			Actions: []string{cmAuth.PushAction},
		},
	}
	signedString, err := cmTokenGenerator.GenerateToken(access, time.Minute*5)
	if err != nil {
		panic(err)
	}

	// Prints a JWT token which you can use to make requests to ChartMuseum
	fmt.Println(signedString)
}
```

This token will be formatted as a valid JSON Web Token (JWT)
and resemble the following:

```
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE1NDM5MjYzODgsImFjY2VzcyI6W3sidHlwZSI6ImhlbG0tcmVwb3NpdG9yeSIsIm5hbWUiOiJvcmcxL3JlcG8xIiwiYWN0aW9ucyI6WyJwdXNoIl19XX0.lDIEwWTwT_PdIBwYAiJ1HXkpgAKkBiHYqX27i4SL_s9tkDLVoN8wUA0jKvwz322ev7Zm8Hu1oDuYft72vDeJkMDUgSC82d36NNmaWLyKau2GD8qsNFiRV5uwrwvJ4j2B-3NE4xJ-FjTcNYvM4Wn2gSwh1QmPYMekgbpIDcdPPa9lnR5K3KPAThLdhti3dQZ75A_3qRAp9Pw8mByeDUuJA-pEbSKPt4tTyecbJe4XON1Xb_sSI_-hoQkbBS_WhRMvKeSq9AONLYEsL4KG2BEALPDl1FEc1-KJVifLy8oWW-vPBZ3TiPaIA7ysot_gE9CgnF7mWoF8af_aD00W_OgBeg
```

You can decode this token on [https://jwt.io](http://jwt.io/#id_token=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE1NDM5MjYzODgsImFjY2VzcyI6W3sidHlwZSI6ImhlbG0tcmVwb3NpdG9yeSIsIm5hbWUiOiJvcmcxL3JlcG8xIiwiYWN0aW9ucyI6WyJwdXNoIl19XX0.lDIEwWTwT_PdIBwYAiJ1HXkpgAKkBiHYqX27i4SL_s9tkDLVoN8wUA0jKvwz322ev7Zm8Hu1oDuYft72vDeJkMDUgSC82d36NNmaWLyKau2GD8qsNFiRV5uwrwvJ4j2B-3NE4xJ-FjTcNYvM4Wn2gSwh1QmPYMekgbpIDcdPPa9lnR5K3KPAThLdhti3dQZ75A_3qRAp9Pw8mByeDUuJA-pEbSKPt4tTyecbJe4XON1Xb_sSI_-hoQkbBS_WhRMvKeSq9AONLYEsL4KG2BEALPDl1FEc1-KJVifLy8oWW-vPBZ3TiPaIA7ysot_gE9CgnF7mWoF8af_aD00W_OgBeg)
or with something like [jwt-cli](https://github.com/mike-engel/jwt-cli).

The decoded payload of this token will look like the following:
```json
{
  "exp": 1543925949,
  "access": [
    {
      "type": "artifact-repository",
      "name": "org1/repo1",
      "actions": [
        "push"
      ]
    }
  ]
}
```

### Making requests to ChartMuseum

First, obtain the token with the necessary access entries (see example above).

Then use this token to make requests to ChartMuseum,
passing it in the `Authorization` header:

```
> GET /api/charts HTTP/1.1
> Host: localhost:8080
> Authorization: Bearer <token>
```

### Validating a JWT token (example)

[Source](./testcmd/decodejwt/main.go)

Clone this repo and run `go run testcmd/decodejwt/main.go <token>` to run this example

```go
package main

import (
	"encoding/json"
	"fmt"
	"os"

	cmAuth "github.com/chartmuseum/auth"

	"github.com/dgrijalva/jwt-go"
)

func main() {
	signedString := os.Args[1]

	// This should be the public key associated with the private key used
	// to sign the token
	cmTokenDecoder, err := cmAuth.NewTokenDecoder(&cmAuth.TokenDecoderOptions{
		PublicKeyPath: "./testdata/server.pem",
	})
	if err != nil {
		panic(err)
	}

	token, err := cmTokenDecoder.DecodeToken(signedString)
	if err != nil {
		panic(err)
	}

	// Inspect the token claims as JSON
	c := token.Claims.(jwt.MapClaims)
	byteData, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		panic(err)
	}
	fmt.Println(string(byteData))
}
```

### Authorizing an incoming request (example)

[Source](./testcmd/authorizer/main.go)

Clone this repo and run `go run testcmd/authorizer/main.go <token>` to run this example

```go
package main

import (
	"fmt"
	"os"

	cmAuth "github.com/chartmuseum/auth"
)

func main() {

	// We are grabbing this from command line, but this should be obtained
	// by inspecting the "Authorization" header of an incoming HTTP request
	signedString := os.Args[1]
	authHeader := fmt.Sprintf("Bearer %s", signedString)

	cmAuthorizer, err := cmAuth.NewAuthorizer(&cmAuth.AuthorizerOptions{
		Realm:         "cm-test-realm",
		PublicKeyPath: "./testdata/server.pem",
	})
	if err != nil {
		panic(err)
	}

	// Example:
	// Check if the auth header provided allows access to push to org1/repo1
	permissions, err := cmAuthorizer.Authorize(authHeader, cmAuth.PushAction, "org1/repo1")
	if err != nil {
		panic(err)
	}

	if permissions.Allowed {
		fmt.Println("ACCESS GRANTED")
	} else {

		// If access is not allowed, the WWWAuthenticateHeader will be populated
		// which should be sent back to the client in the "WWW-Authenticate" header
		fmt.Println("ACCESS DENIED")
		fmt.Println(fmt.Sprintf("WWW-Authenticate: %s", permissions.WWWAuthenticateHeader))
	}
}
```

## Supported JWT Signing Algorithms

- RS256
