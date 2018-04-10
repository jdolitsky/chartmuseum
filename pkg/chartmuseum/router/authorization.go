package router

import (
	"crypto/rsa"
	"encoding/base64"
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"strings"

	"github.com/dgrijalva/jwt-go"
)

type (
	AccessEntry struct {
		Type    string   `json:"type"`
		Name    string   `json:"name"`
		Actions []action `json:"actions"`
	}

	CustomClaims struct {
		*jwt.StandardClaims
		Access []AccessEntry `json:"http://localhost:8080/access"`
	}
)

var (
	verifyKey *rsa.PublicKey
)

func (claims *CustomClaims) repoActionAllowed(repo string, act action) bool {
	for _, entry := range claims.Access {
		if entry.Type == "repository" {
			if entry.Name == repo {
				for _, a := range entry.Actions {
					if a == act {
						return true
					}
				}
			}
		}
	}
	return false
}

func isRepoAction(act action) bool {
	return act == RepoPullAction || act == RepoPushAction
}

func generateBasicAuthHeader(username string, password string) string {
	base := username + ":" + password
	basicAuthHeader := "Basic " + base64.StdEncoding.EncodeToString([]byte(base))
	return basicAuthHeader
}

func (router *Router) authorizeRequest(repo string, act action, request *http.Request) (bool, map[string]string) {
	authorized := false
	responseHeaders := map[string]string{}

	if act == RepoPushAction {
		token, err := extractRequestToken(request)
		if token == nil {
			if err != nil {
				fmt.Println(err)
			}
		} else {
			switch err.(type) {
			case nil:
				if !token.Valid {
					fmt.Println("invalid token")
				} else {
					claims := token.Claims.(*CustomClaims)
					if claims.repoActionAllowed(repo, act) {
						authorized = true
					}
				}
			case *jwt.ValidationError:
				vErr := err.(*jwt.ValidationError)
				switch vErr.Errors {
				case jwt.ValidationErrorExpired:
					fmt.Println("token expired")
				default:
					fmt.Println("could not parse token")
				}
			default: // something else went wrong
				fmt.Println(err)
				fmt.Println("unknown error")
			}
		}

		if !authorized {
			wwwAuth := fmt.Sprintf(
				"Bearer realm=\"https://chartmuseum.auth0.com/oauth/token\",scope=\"repository:%s:pull,push\"",
				repo,
			)
			responseHeaders["WWW-Authenticate"] = wwwAuth
		}

	} else {
		// BasicAuthHeader is only set on the router if ChartMuseum is configured to use
		// basic auth protection. If not set, the server and all its routes are wide open.
		if router.BasicAuthHeader != "" {
			if router.AnonymousGet && request.Method == "GET" {
				authorized = true
			} else if request.Header.Get("Authorization") == router.BasicAuthHeader {
				authorized = true
			} else {
				responseHeaders["WWW-Authenticate"] = "Basic realm=\"ChartMuseum\""
			}
		} else {
			authorized = true
		}
	}

	return authorized, responseHeaders
}

func extractRequestToken(request *http.Request) (*jwt.Token, error) {
	h := request.Header.Get("Authorization")
	if h == "" {
		return nil, errors.New("missing authorization header")
	}
	tmp := strings.Split(h, "Bearer ")
	if len(tmp) != 2 {
		return nil, errors.New("authorization header malformed")
	}
	raw := tmp[1]
	return jwt.ParseWithClaims(raw, &CustomClaims{}, func(token *jwt.Token) (interface{}, error) {
		return verifyKey, nil
	})
}

// read the key files before starting http handlers
func init() {
	verifyBytes, err := ioutil.ReadFile("/tmp/chartmuseum.pem")
	if err != nil {
		panic(err)
	}
	verifyKey, err = jwt.ParseRSAPublicKeyFromPEM(verifyBytes)
	if err != nil {
		panic(err)
	}
}
